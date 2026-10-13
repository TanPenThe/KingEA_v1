"""Synthetic-only specification tests for prospective native cost evidence.

This file deliberately does not call MT5, history APIs, Candidate 001, or an
order path.  It defines the evidence requirements a later approved adapter must
meet; it is not the production ledger implementation.
"""

from dataclasses import dataclass
import math
import unittest


@dataclass(frozen=True)
class GroupBinding:
    run_id: str
    configuration_id: int
    branch: str
    partition: str
    trade_group_id: str
    position_identifier: int


@dataclass(frozen=True)
class SealedCostSnapshot:
    quote_time_msc: int
    entry_commission: float
    entry_fee: float
    cumulative_swap: float

    @property
    def actual_costs(self) -> float:
        return self.entry_commission + self.entry_fee + self.cumulative_swap


class ProspectiveNativeCostLedgerFixture:
    """A fail-closed reference model for current-run-only cost evidence."""

    def __init__(self, binding: GroupBinding) -> None:
        self.binding = binding
        self._entry_deal_ticket: int | None = None
        self._entry_commission: float | None = None
        self._entry_fee: float | None = None
        self._sealed: SealedCostSnapshot | None = None

    def capture_entry_deal(self, *, binding: GroupBinding, deal_ticket: int,
                           source_event: str, commission: float, fee: float) -> None:
        if binding != self.binding or source_event != "CURRENT_RUN_NATIVE_EXECUTION_ACCOUNTING_METADATA_ONLY":
            raise ValueError("FOREIGN_OR_PRIOR_RUN_DEAL_METADATA")
        if deal_ticket <= 0 or not math.isfinite(commission) or not math.isfinite(fee):
            raise ValueError("DEAL_METADATA_INVALID")
        if self._entry_deal_ticket is not None:
            raise ValueError("DUPLICATE_DEAL_METADATA")
        self._entry_deal_ticket = deal_ticket
        self._entry_commission = commission
        self._entry_fee = fee

    def seal_pre_end_snapshot(self, *, binding: GroupBinding, quote_time_msc: int,
                               end_msc: int, cumulative_swap: float) -> SealedCostSnapshot:
        if binding != self.binding:
            raise ValueError("WRONG_TRADE_GROUP_BINDING")
        if self._sealed is not None:
            raise ValueError("POST_SEAL_COST_MUTATION")
        if (self._entry_deal_ticket is None or quote_time_msc <= 0 or
                quote_time_msc >= end_msc or not math.isfinite(cumulative_swap)):
            raise ValueError("PRE_END_COST_SNAPSHOT_UNPROVEN")
        self._sealed = SealedCostSnapshot(
            quote_time_msc, self._entry_commission, self._entry_fee, cumulative_swap
        )
        return self._sealed

    def boundary_net(self, *, direction: str, entry_price: float, volume: float,
                     retained_bid: float, retained_ask: float, quote_time_msc: int,
                     order_calc_profit) -> float:
        if direction not in {"LONG", "SHORT"}:
            raise ValueError("INVALID_DIRECTION")
        if self._sealed is None or quote_time_msc != self._sealed.quote_time_msc:
            raise ValueError("PRE_END_COST_SNAPSHOT_UNPROVEN")
        if not all(math.isfinite(x) and x > 0 for x in
                   (entry_price, volume, retained_bid, retained_ask)) or retained_ask < retained_bid:
            raise ValueError("BOUNDARY_QUOTE_OR_POSITION_INVALID")
        exit_price = retained_bid if direction == "LONG" else retained_ask
        return order_calc_profit(direction, volume, entry_price, exit_price) + self._sealed.actual_costs


class NativeCostLedgerAuditTests(unittest.TestCase):
    BINDING = GroupBinding("RUN-1", 7168, "RECORDED", "FOLD_1_TRAIN", "GROUP-1", 77)
    END = 10_000
    QUOTE = 9_999

    @staticmethod
    def native_order_calc_profit(direction: str, volume: float, entry: float, exit_: float) -> float:
        return (exit_ - entry) * volume if direction == "LONG" else (entry - exit_) * volume

    def ledger_with_entry(self) -> ProspectiveNativeCostLedgerFixture:
        ledger = ProspectiveNativeCostLedgerFixture(self.BINDING)
        ledger.capture_entry_deal(binding=self.BINDING, deal_ticket=123,
                                  source_event="CURRENT_RUN_NATIVE_EXECUTION_ACCOUNTING_METADATA_ONLY",
                                  commission=-1.25, fee=-0.25)
        return ledger

    def test_actual_entry_commission_and_fee_are_captured_once(self) -> None:
        ledger = self.ledger_with_entry()
        with self.assertRaisesRegex(ValueError, "DUPLICATE_DEAL_METADATA"):
            ledger.capture_entry_deal(binding=self.BINDING, deal_ticket=123,
                                      source_event="CURRENT_RUN_NATIVE_EXECUTION_ACCOUNTING_METADATA_ONLY",
                                      commission=-1.25, fee=-0.25)
        snapshot = ledger.seal_pre_end_snapshot(binding=self.BINDING, quote_time_msc=self.QUOTE,
                                                end_msc=self.END, cumulative_swap=-0.50)
        self.assertEqual(snapshot.actual_costs, -2.0)

    def test_pre_end_swap_snapshot_is_sealed_and_post_end_mutation_is_rejected(self) -> None:
        ledger = self.ledger_with_entry()
        snapshot = ledger.seal_pre_end_snapshot(binding=self.BINDING, quote_time_msc=self.QUOTE,
                                                end_msc=self.END, cumulative_swap=-0.50)
        with self.assertRaisesRegex(ValueError, "POST_SEAL_COST_MUTATION"):
            ledger.seal_pre_end_snapshot(binding=self.BINDING, quote_time_msc=10_001,
                                         end_msc=self.END, cumulative_swap=-999.0)
        self.assertEqual(snapshot.actual_costs, -2.0)

    def test_long_and_short_use_pre_end_bid_ask_without_double_charging(self) -> None:
        long_ledger = self.ledger_with_entry()
        long_ledger.seal_pre_end_snapshot(binding=self.BINDING, quote_time_msc=self.QUOTE,
                                          end_msc=self.END, cumulative_swap=-0.50)
        self.assertEqual(long_ledger.boundary_net(direction="LONG", entry_price=100.0, volume=2.0,
                                                   retained_bid=99.0, retained_ask=101.0,
                                                   quote_time_msc=self.QUOTE,
                                                   order_calc_profit=self.native_order_calc_profit), -4.0)
        short_ledger = self.ledger_with_entry()
        short_ledger.seal_pre_end_snapshot(binding=self.BINDING, quote_time_msc=self.QUOTE,
                                           end_msc=self.END, cumulative_swap=-0.50)
        self.assertEqual(short_ledger.boundary_net(direction="SHORT", entry_price=100.0, volume=2.0,
                                                    retained_bid=99.0, retained_ask=101.0,
                                                    quote_time_msc=self.QUOTE,
                                                    order_calc_profit=self.native_order_calc_profit), -4.0)

    def test_missing_or_foreign_evidence_and_invalid_direction_fail_closed(self) -> None:
        ledger = ProspectiveNativeCostLedgerFixture(self.BINDING)
        with self.assertRaisesRegex(ValueError, "PRE_END_COST_SNAPSHOT_UNPROVEN"):
            ledger.seal_pre_end_snapshot(binding=self.BINDING, quote_time_msc=self.QUOTE,
                                         end_msc=self.END, cumulative_swap=0.0)
        foreign = GroupBinding("OLD-RUN", 7168, "RECORDED", "FOLD_1_TRAIN", "GROUP-1", 77)
        with self.assertRaisesRegex(ValueError, "FOREIGN_OR_PRIOR_RUN_DEAL_METADATA"):
            ledger.capture_entry_deal(binding=foreign, deal_ticket=123,
                                      source_event="CURRENT_RUN_NATIVE_EXECUTION_ACCOUNTING_METADATA_ONLY",
                                      commission=-1.0, fee=0.0)
        ledger = self.ledger_with_entry()
        with self.assertRaisesRegex(ValueError, "WRONG_TRADE_GROUP_BINDING"):
            ledger.seal_pre_end_snapshot(binding=GroupBinding("RUN-1", 7168, "RSB3", "FOLD_1_TRAIN", "GROUP-1", 77),
                                         quote_time_msc=self.QUOTE, end_msc=self.END, cumulative_swap=0.0)
        ledger.seal_pre_end_snapshot(binding=self.BINDING, quote_time_msc=self.QUOTE,
                                     end_msc=self.END, cumulative_swap=0.0)
        with self.assertRaisesRegex(ValueError, "INVALID_DIRECTION"):
            ledger.boundary_net(direction="INVALID", entry_price=100.0, volume=1.0,
                                retained_bid=99.0, retained_ask=101.0, quote_time_msc=self.QUOTE,
                                order_calc_profit=self.native_order_calc_profit)


if __name__ == "__main__":
    unittest.main()
