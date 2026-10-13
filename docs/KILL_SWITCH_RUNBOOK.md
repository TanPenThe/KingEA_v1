# KingEA Independent Kill-Switch Runbook

Status: Required demo drill before first live deployment  
Last verified against platform documentation: 2026-07-28  
Scope: Dedicated JustMarkets MT5 KingEA account

## When to use

Use immediately for uncontrolled/repeated orders, missing stops, exposure above caps, corrupted state, inability to trust EA/watchdog output, unexplained positions, or any situation where the automated stack may be unsafe.

This procedure bypasses KingEA. Do not wait for its circuit breakers or alerts.

## Primary procedure — trading PC is reachable

1. Create and verify the persistent manual-standdown latch before stopping MT5:
   - Run `operations\Set-KingEAStanddown.ps1` from the independently stored emergency shortcut with the exact deployment ID, operator name, and incident reason.
   - Require the `KINGEA_STANDDOWN_ACTIVE` confirmation and record the returned path.
2. If the standdown helper cannot run, its output is unclear, or its latch cannot be verified, independently stop or disable the KingEA watchdog before touching MT5. Do not assume stopping MT5 also stops the watchdog.
3. Only after step 1 or the fallback in step 2 succeeds, click **Algo Trading** in the MT5 desktop toolbar so automated trading is disabled globally. Confirm the toolbar state is disabled. As a second check, open **Tools -> Options -> Expert Advisors** and confirm **Allow Auto Trading** is off.
4. Stop any hosted duplicate before flattening:
   - If using MetaTrader virtual hosting, open **Navigator -> VPS**, select the active server, and choose **Stop**.
   - If using a third-party VPS, stop the trading terminal/session through the provider console.
5. Open **View -> Toolbox -> Trade**.
6. Right-click inside the positions area and use **Group operations -> Close all positions** when available. If unavailable, close every position individually using **Close Position** or the close button in the Profit column.
7. Right-click inside the pending-orders area and use **Group operations -> Delete all pending orders**. If unavailable, open each order with **Modify or Delete**, then choose **Delete**.
8. Refresh/reconnect and confirm the **Trade** tab contains zero open positions and zero pending orders. Do not rely on an earlier success dialog.
9. Remove/disable the KingEA instance from **Navigator -> Expert Advisors** or close MT5 after confirming the account is flat.
10. Record the incident time, account, screenshots, tickets, rejected closures, and final broker-confirmed state. Leave the deployment quarantined.

The EA and watchdog may never remove the standdown latch. Clearing it requires
documented manual review, broker-inventory reconciliation, and explicit owner
approval.

## Alternate procedure — use a separate mobile device/network

First prevent the remote automated terminal from sending new orders. Physically stop/disconnect the trading PC, stop the VPS from its provider control panel, or use another broker-supported method to revoke/stop that trading session. Closing positions from mobile while the EA remains active is insufficient because it may reopen them.

Then in the MT5 mobile app:

1. Open the dedicated account and select the **Trade** tab.
2. Open **Bulk operations** in the Positions section and select **Close all positions**. If bulk operations are unavailable, long-press/swipe each position, choose **Close position**, and confirm the full volume.
3. Open **Bulk operations** in the Orders section and delete all pending orders. If unavailable, long-press/swipe each order and choose **Delete order**.
4. Refresh and confirm zero positions and zero pending orders.
5. Save screenshots and leave KingEA quarantined until documented revalidation.

## If electronic closing is impossible

- Contact JustMarkets through the Personal Area **Support Hub** or 24/7 support.
- Official contact page: https://justmarkets.com/support/contact-information
- English support numbers listed on 2026-07-21: `+248 4632027`, `+230 52970330`.
- State that the request concerns an urgent live trading-account position/order closure. Confirm the account through the broker's approved identity process; never place passwords in repository files or ordinary chat/email.
- Record the case/ticket number and verify the final account state through an independent login when access returns.

Contact details must be reverified during every quarterly kill-switch drill.

## Completion criteria

- Automated terminal/session is unable to submit new orders.
- Broker account shows no open positions.
- Broker account shows no pending orders.
- Incident evidence is saved.
- Persistent quarantine is active.
- No automatic restart or resume is permitted.

## Drill record

Append drill results below; never overwrite earlier entries.

### DRILL-PENDING-001

- Environment: JustMarkets demo
- Status: NOT RUN
- Required before: first live deployment
- Required evidence: start/end screenshots, terminal/VPS stop proof, position/order tickets, closure confirmation, elapsed time, any errors, and corrective actions.

### DRILL-DEMO-001

- Environment: `JustMarkets-Demo2`; account identity stored only as redacted suffix and SHA-256 fingerprint.
- Date: 2026-07-28.
- Status: PASS — deployment remains quarantined.
- Fixtures: one `0.01` ETHUSD.s Buy with broker-side SL and one `0.01` ETHUSD.s Buy Limit with broker-side SL and GTC fallback.
- Result: the mobile device manually closed the full position and deleted the pending order; mobile and desktop independently showed zero inventory.
- Standdown: created before automation shutdown and retained after the drill.
- Watchdog: one foreground `-Once` evaluation emitted `STANDDOWN / MANUAL_STANDDOWN_ACTIVE`; no process action occurred.
- Shutdown: MT5 remained absent throughout a measured 76-second observation; no KingEA scheduled task existed.
- Evidence record: `governance\drills\DRILL-DEMO-001.json`.
- Latch removal remains prohibited without broker reconciliation, documented review, and explicit owner approval.

## Official platform references

- Disable automated trading: https://www.metatrader5.com/en/terminal/help/algotrading/trade_robots_indicators
- Desktop position and pending-order management: https://www.metatrader5.com/en/terminal/help/trading/performing_deals
- Android close-position procedure: https://www.metatrader5.com/en/mobile-trading/android/help/trade/open_positions
- Android bulk operations: https://www.metatrader5.com/en/mobile-trading/android/help/trade/bulk_operations
- iPhone/iPad trade controls: https://www.metatrader5.com/en/mobile-trading/iphone/help/trade
- iPhone/iPad bulk operations: https://www.metatrader5.com/en/mobile-trading/iphone/help/trade/bulk_operations
