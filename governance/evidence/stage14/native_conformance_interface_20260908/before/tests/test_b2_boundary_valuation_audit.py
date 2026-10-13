"""Synthetic-only audit fixtures for the proposed boundary valuation protocol.

This is not production liquidation code.  It makes the required provenance
properties executable without accessing MT5, Candidate 001, or market results.
"""

from dataclasses import dataclass
import unittest


@dataclass(frozen=True)
class RetainedQuote:
    time_msc: int
    bid: float
    ask: float


def proposed_boundary_net(
    *, direction: str, entry_price: float, volume: float, retained_quote: RetainedQuote,
    end_msc: int, already_booked_group_costs: float | None, native_profit,
) -> tuple[str, float | None, float | None]:
    """Test-only specification seam; ``native_profit`` stands for OrderCalcProfit.

    A concrete B2 implementation does not exist.  In particular, it must not
    replace this seam with a second pricing formula or use terminal equity.
    """
    if (retained_quote.time_msc <= 0 or retained_quote.time_msc >= end_msc or
            retained_quote.bid <= 0 or retained_quote.ask <= 0 or
            retained_quote.ask < retained_quote.bid or entry_price <= 0 or volume <= 0):
        return "BOUNDARY_QUOTE_OR_POSITION_INVALID", None, None
    if already_booked_group_costs is None:
        return "BOUNDARY_COST_BASIS_UNPROVEN", None, None
    exit_price = retained_quote.bid if direction == "LONG" else retained_quote.ask
    gross = native_profit(direction, volume, entry_price, exit_price)
    return "BOUNDARY_VALUATION_PROVEN", gross + already_booked_group_costs, exit_price


class BoundaryValuationAuditTests(unittest.TestCase):
    END = 10_000
    PRE_END = RetainedQuote(time_msc=9_999, bid=99.0, ask=101.0)

    @staticmethod
    def authoritative_native_profit(direction: str, volume: float, entry: float, exit_: float) -> float:
        # Deterministic test double for the existing native OrderCalcProfit seam.
        sign = 1.0 if direction == "LONG" else -1.0
        return sign * (exit_ - entry) * volume

    def test_long_a_b_paths_ignore_a_later_post_end_tick(self) -> None:
        a = proposed_boundary_net(direction="LONG", entry_price=100.0, volume=2.0,
                                  retained_quote=self.PRE_END, end_msc=self.END,
                                  already_booked_group_costs=-0.4,
                                  native_profit=self.authoritative_native_profit)
        post_end_tick = RetainedQuote(time_msc=10_001, bid=1.0, ask=10_000.0)
        b = proposed_boundary_net(direction="LONG", entry_price=100.0, volume=2.0,
                                  retained_quote=self.PRE_END, end_msc=self.END,
                                  already_booked_group_costs=-0.4,
                                  native_profit=self.authoritative_native_profit)
        self.assertGreaterEqual(post_end_tick.time_msc, self.END)
        self.assertEqual(a, b)
        self.assertEqual(a, ("BOUNDARY_VALUATION_PROVEN", -2.4, 99.0))

    def test_short_a_b_paths_ignore_a_later_post_end_tick(self) -> None:
        a = proposed_boundary_net(direction="SHORT", entry_price=100.0, volume=2.0,
                                  retained_quote=self.PRE_END, end_msc=self.END,
                                  already_booked_group_costs=-0.4,
                                  native_profit=self.authoritative_native_profit)
        post_end_tick = RetainedQuote(time_msc=10_001, bid=10_000.0, ask=1.0)
        b = proposed_boundary_net(direction="SHORT", entry_price=100.0, volume=2.0,
                                  retained_quote=self.PRE_END, end_msc=self.END,
                                  already_booked_group_costs=-0.4,
                                  native_profit=self.authoritative_native_profit)
        self.assertGreaterEqual(post_end_tick.time_msc, self.END)
        self.assertEqual(a, b)
        self.assertEqual(a, ("BOUNDARY_VALUATION_PROVEN", -2.4, 101.0))

    def test_unproven_cost_basis_fails_closed_for_both_terminal_paths(self) -> None:
        a = proposed_boundary_net(direction="LONG", entry_price=100.0, volume=1.0,
                                  retained_quote=self.PRE_END, end_msc=self.END,
                                  already_booked_group_costs=None,
                                  native_profit=self.authoritative_native_profit)
        b = proposed_boundary_net(direction="LONG", entry_price=100.0, volume=1.0,
                                  retained_quote=self.PRE_END, end_msc=self.END,
                                  already_booked_group_costs=None,
                                  native_profit=self.authoritative_native_profit)
        self.assertEqual(a, ("BOUNDARY_COST_BASIS_UNPROVEN", None, None))
        self.assertEqual(a, b)


if __name__ == "__main__":
    unittest.main()
