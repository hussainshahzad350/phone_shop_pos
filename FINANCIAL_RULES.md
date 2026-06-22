# Phone Shop POS — Official Financial Rules Specification

**Version:** 1.0  
**Date:** 2026-06-22  
**Authority:** This document is the single source of truth for all financial logic in Phone Shop POS.  
**Scope:** All modules — Sales, Purchases, Returns, Expenses, Damages, Dealer Issues, Inventory, Reporting.

---

## TABLE OF CONTENTS

1. Business Entities
2. Money Flow Model
3. Profit Rules
4. Inventory Rules
5. Return Rules
6. Discount Rules
7. Damage Rules
8. Dealer Issue Rules
9. Reporting Rules
10. Edge Cases
11. Test Scenarios (50+)

---

# PART 1 — BUSINESS ENTITIES

## 1.1 Product

**Definition:** A sellable item stocked in the shop. Products are either Mobile Phones or Accessories.

**Attributes:**
- `product_id` — unique identifier
- `name` — descriptive name (e.g., "iPhone 15 Pro 256GB Black")
- `sku` — stock-keeping unit / barcode
- `category` — PHONE or ACCESSORY
- `cost_price` — most recent purchase cost per unit
- `selling_price` — default selling price per unit
- `current_stock_qty` — quantity currently on hand (integer, never negative by policy)

**Role:** Products are the base unit of all inventory, sales, and purchase transactions. Every financial transaction originates from a product.

---

## 1.2 Inventory

**Definition:** The real-time record of how many units of each product are physically available for sale.

**Attributes:**
- `product_id`
- `quantity_on_hand` — current sellable units
- `average_cost` — weighted average cost per unit (updated on each purchase)
- `total_inventory_value` = `quantity_on_hand × average_cost`

**Role:** Inventory is the foundation of COGS calculation and stock reporting. Every stock movement — whether from a sale, purchase, return, damage, or adjustment — must update inventory immediately and atomically.

**Cost Method:** Weighted Average Cost (WAC). Chosen for simplicity in retail without FIFO complexity.

**WAC Formula:**
```
new_average_cost = (old_qty × old_avg_cost + new_qty × new_unit_cost)
                   ÷ (old_qty + new_qty)
```

---

## 1.3 Sale

**Definition:** A transaction in which one or more products are sold to a customer at agreed prices.

**Attributes:**
- `sale_id`
- `sale_date`
- `customer_id` (nullable — walk-in customer)
- `sale_items[]` — list of Sale Items
- `subtotal` — sum of all line item totals before invoice discount
- `invoice_discount` — discount applied to the whole invoice (fixed amount)
- `grand_total` = `subtotal − invoice_discount`
- `amount_paid` — cash/payment received at time of sale
- `balance_due` = `grand_total − amount_paid`
- `payment_method` — CASH, CREDIT, PARTIAL
- `status` — ACTIVE, RETURNED (fully), PARTIAL_RETURNED

**Role:** A sale is the primary revenue-generating event. It triggers stock decrease, revenue recognition, and (if credit) customer balance increase.

---

## 1.4 Sale Item

**Definition:** A single line within a sale representing one product.

**Attributes:**
- `sale_item_id`
- `sale_id`
- `product_id`
- `quantity`
- `unit_price` — selling price per unit at time of sale (snapshot)
- `line_discount` — discount on this specific line (fixed amount)
- `line_total` = `(unit_price × quantity) − line_discount`
- `unit_cost_at_sale` — average cost per unit at time of sale (snapshot for COGS)
- `cogs` = `unit_cost_at_sale × quantity`

**Role:** Each sale item drives stock reduction and COGS recognition. The `unit_cost_at_sale` must be captured as a snapshot at the moment of the sale — it must not change if the product's cost changes later.

---

## 1.5 Purchase

**Definition:** A transaction in which products are acquired from a supplier.

**Attributes:**
- `purchase_id`
- `purchase_date`
- `supplier_id`
- `purchase_items[]`
- `subtotal` — sum of all line item totals
- `grand_total` = `subtotal` (purchases generally have no invoice discount unless explicitly modeled)
- `amount_paid`
- `balance_due` = `grand_total − amount_paid`
- `payment_method` — CASH, CREDIT, PARTIAL
- `status` — ACTIVE, RETURNED (fully), PARTIAL_RETURNED

**Role:** A purchase increases stock and creates a cost basis (inventory value). If not paid in full it creates a supplier liability (payable).

---

## 1.6 Purchase Item

**Definition:** A single line within a purchase.

**Attributes:**
- `purchase_item_id`
- `purchase_id`
- `product_id`
- `quantity`
- `unit_cost` — cost per unit paid to supplier
- `line_total` = `unit_cost × quantity`

**Role:** Updates inventory quantity and recalculates weighted average cost.

---

## 1.7 Sales Return

**Definition:** A transaction where a customer returns previously purchased items.

**Attributes:**
- `return_id`
- `original_sale_id`
- `return_date`
- `return_items[]` — products and quantities returned
- `total_return_value` — the revenue reversed
- `refund_method` — CASH_REFUND, CREDIT_NOTE, BALANCE_ADJUSTMENT
- `refund_amount` — actual cash refunded (may differ from return value if credit note)

**Role:** A sales return reverses revenue and COGS proportionally. Stock is restored. A partial return reverses only the affected items.

---

## 1.8 Purchase Return

**Definition:** A transaction where the shop returns items to a supplier.

**Attributes:**
- `purchase_return_id`
- `original_purchase_id`
- `return_date`
- `return_items[]`
- `total_return_value`
- `refund_method` — CASH_RECEIVED, CREDIT_NOTE, BALANCE_ADJUSTMENT

**Role:** A purchase return decreases stock, reduces cost basis, and decreases supplier liability (or generates cash inflow).

---

## 1.9 Expense

**Definition:** An operating cost that is not tied to the purchase or sale of inventory.

**Attributes:**
- `expense_id`
- `expense_date`
- `category` — e.g., RENT, UTILITIES, SALARY, TRANSPORT, MARKETING, OTHER
- `amount`
- `description`
- `payment_method` — CASH or BANK

**Role:** Expenses reduce net profit. They do not affect stock or gross profit. They affect cash flow directly.

---

## 1.10 Damage

**Definition:** A record of inventory that has become unsellable due to physical damage, theft, or loss.

**Attributes:**
- `damage_id`
- `damage_date`
- `product_id`
- `quantity`
- `unit_cost` — cost per unit (average cost at time of damage)
- `total_loss` = `unit_cost × quantity`
- `reason` — BROKEN, THEFT, LOST, WATER_DAMAGE, OTHER

**Role:** Damage removes stock and creates an inventory loss (a cost that reduces net profit). No revenue is generated from damaged goods.

---

## 1.11 Dealer Issue

**Definition:** Stock physically transferred to a dealer/agent on a trial or consignment basis, without a confirmed sale.

**Attributes:**
- `dealer_issue_id`
- `issue_date`
- `dealer_id` — treated as a customer
- `issue_items[]` — products and quantities
- `status` — PENDING, RETURNED (fully), CONVERTED_TO_SALE, PARTIAL

**Role:** A dealer issue moves stock out of the shop into a "with dealer" state. It is NOT a sale at the time of issue. No revenue, no profit. The financial event occurs only upon conversion to sale or recording as damage/loss.

---

## 1.12 Dealer Return

**Definition:** Dealer returns previously issued items back to the shop.

**Attributes:**
- `dealer_return_id`
- `original_dealer_issue_id`
- `return_date`
- `return_items[]`

**Role:** Stock re-enters the shop inventory. No financial impact beyond stock restoration.

---

## 1.13 Customer

**Definition:** A person or business that buys products from the shop.

**Attributes:**
- `customer_id`
- `name`
- `phone`
- `total_purchases` — lifetime purchase value
- `total_payments_received` — total cash collected
- `outstanding_balance` = `total_purchases − total_payments_received` (net of returns)

**Outstanding Balance Rule:**  
A positive balance means the customer owes money.  
A negative balance means the shop owes the customer (overpayment or credit note).

---

## 1.14 Supplier

**Definition:** A business or individual from which the shop buys inventory.

**Attributes:**
- `supplier_id`
- `name`
- `phone`
- `total_purchases_from` — total value of goods purchased
- `total_payments_made` — total cash paid to supplier
- `outstanding_balance` = `total_purchases_from − total_payments_made` (net of returns)

**Outstanding Balance Rule:**  
A positive balance means the shop owes the supplier.  
A negative balance means the supplier owes the shop (overpayment or return credit).

---

## 1.15 Cash Account

**Definition:** Tracks the physical cash held by the shop.

**Attributes:**
- `cash_balance` — current balance

**Rule:** Cash is affected by: sales (cash portion), purchases (cash portion), expenses, returns (refunds), received payments, paid payments, and damages (if compensation received — rare).

**Cash Balance Formula:**
```
Cash Balance = Opening Cash
             + Cash Sales
             + Cash Received from Customers
             − Cash Purchases
             − Cash Paid to Suppliers
             − Cash Expenses
             − Cash Refunds to Customers
             + Cash Received from Suppliers (purchase returns)
             + Cash from Stock Adjustments (if any)
```

---

## 1.16 Profit

**Definition:** The financial gain after subtracting all costs from revenues.

**Types:**
- **Gross Profit** — Revenue minus direct cost of goods sold
- **Net Profit** — Gross Profit minus all operating expenses, damage losses, and other losses

**Role:** Profit is a calculated metric, never stored directly — it is always derived from the combination of sales, COGS, returns, expenses, and damages.

---

# PART 2 — MONEY FLOW MODEL

## 2.1 Legend

| Symbol | Meaning |
|--------|---------|
| + | Increases |
| − | Decreases |
| 0 | No effect |
| → | Transfers to |

## 2.2 Purchase

**Scenario:** Shop buys 10 iPhones from supplier at cost PKR 80,000 each. Pays PKR 500,000 cash and PKR 300,000 on credit.

| Dimension | Effect | Formula |
|-----------|--------|---------|
| Stock | + 10 units | qty_on_hand += 10 |
| Cash | − 500,000 | cash_balance −= amount_paid |
| Customer Balance | 0 | — |
| Supplier Balance | + 300,000 | supplier.outstanding += balance_due |
| Revenue | 0 | — |
| COGS Basis | + 800,000 | inventory_value += total_purchase_cost |
| Profit (immediate) | 0 | Profit realized on sale, not purchase |

**WAC Recalculation:**
```
If existing stock = 5 units at avg_cost = PKR 75,000
New purchase: 10 units at PKR 80,000

new_avg_cost = (5 × 75,000 + 10 × 80,000) ÷ (5 + 10)
             = (375,000 + 800,000) ÷ 15
             = 1,175,000 ÷ 15
             = PKR 78,333.33
```

---

## 2.3 Purchase Return

**Scenario:** Shop returns 2 iPhones to supplier (avg_cost PKR 78,333 each). Supplier refunds PKR 100,000 cash and credits PKR 56,666.

| Dimension | Effect | Formula |
|-----------|--------|---------|
| Stock | − 2 units | qty_on_hand −= 2 |
| Cash | + 100,000 | cash_balance += cash_refund_received |
| Customer Balance | 0 | — |
| Supplier Balance | − 156,666 | supplier.outstanding −= total_return_value |
| Revenue | 0 | — |
| COGS Basis | − 156,666 | inventory_value −= (avg_cost × qty_returned) |
| Profit | 0 | No profit impact |

**WAC Recalculation after return:**
```
Stock before return: 15 units at PKR 78,333
Return 2 units.
Remaining: 13 units at PKR 78,333 (avg_cost unchanged on return)
```

---

## 2.4 Sale

**Scenario:** Sell 2 iPhones at PKR 95,000 each. Invoice discount PKR 5,000. Customer pays PKR 100,000 cash, PKR 85,000 on credit. Avg cost = PKR 78,333.

| Dimension | Effect | Formula |
|-----------|--------|---------|
| Stock | − 2 units | qty_on_hand −= 2 |
| Cash | + 100,000 | cash_balance += amount_paid |
| Customer Balance | + 85,000 | customer.outstanding += balance_due |
| Supplier Balance | 0 | — |
| Revenue | + 185,000 | grand_total = (95,000×2) − 5,000 = 185,000 |
| COGS | + 156,666 | unit_cost_at_sale × qty = 78,333 × 2 |
| Gross Profit | + 28,334 | revenue − COGS = 185,000 − 156,666 |

**Note:** The `unit_cost_at_sale` is the WAC at the moment of sale. It is locked to this sale forever.

---

## 2.5 Sale Return

**Scenario:** Customer returns 1 iPhone from the sale above. Refund by cash PKR 90,000. (Sale was: 1 unit at PKR 95,000, prorated invoice discount PKR 2,500 → net PKR 92,500.)

| Dimension | Effect | Formula |
|-----------|--------|---------|
| Stock | + 1 unit | qty_on_hand += 1 |
| Cash | − 90,000 | cash_balance −= cash_refunded |
| Customer Balance | − 2,500 | customer.outstanding −= (return_value − cash_refunded) |
| Supplier Balance | 0 | — |
| Revenue | − 92,500 | reverse prorated revenue of returned item |
| COGS | − 78,333 | reverse COGS of returned item |
| Gross Profit | − 14,167 | revenue_reversed − COGS_reversed |

**Stock note:** Returned stock re-enters inventory at the original `unit_cost_at_sale` (PKR 78,333). WAC is recalculated.

```
Before return: 11 units at PKR 78,333
Add 1 returned unit at PKR 78,333
After return: 12 units at PKR 78,333 (WAC unchanged in this case)
```

---

## 2.6 Expense

**Scenario:** Shop pays PKR 15,000 rent in cash.

| Dimension | Effect | Formula |
|-----------|--------|---------|
| Stock | 0 | — |
| Cash | − 15,000 | cash_balance −= expense_amount |
| Customer Balance | 0 | — |
| Supplier Balance | 0 | — |
| Revenue | 0 | — |
| COGS | 0 | — |
| Net Profit | − 15,000 | expenses reduce net profit directly |

---

## 2.7 Damage

**Scenario:** 1 iPhone damaged (cracked screen, unsellable). Avg cost PKR 78,333.

| Dimension | Effect | Formula |
|-----------|--------|---------|
| Stock | − 1 unit | qty_on_hand −= 1 |
| Cash | 0 | — |
| Customer Balance | 0 | — |
| Supplier Balance | 0 | — |
| Revenue | 0 | — |
| Damage Loss | + 78,333 | unit_avg_cost × qty_damaged |
| Net Profit | − 78,333 | damage_loss reduces net profit |

---

## 2.8 Discount

**Discounts are embedded within Sale or Sale Item, not a separate transaction. Their effects are:**

| Dimension | Effect | Formula |
|-----------|--------|---------|
| Stock | 0 | — |
| Cash | 0 (discount reduces what is charged, not what was in cash) | — |
| Revenue | − discount_amount | Net revenue = gross price − discount |
| COGS | 0 | COGS is cost-based, not price-based |
| Gross Profit | − discount_amount | Profit is lower due to reduced revenue |

---

## 2.9 Cash Received (from customer after sale)

**Scenario:** Customer pays PKR 85,000 outstanding balance.

| Dimension | Effect | Formula |
|-----------|--------|---------|
| Stock | 0 | — |
| Cash | + 85,000 | cash_balance += amount_received |
| Customer Balance | − 85,000 | customer.outstanding −= amount_received |
| Revenue | 0 | Revenue was recorded at time of sale |
| Profit | 0 | No profit change — this is a balance settlement |

---

## 2.10 Cash Paid (to supplier)

**Scenario:** Shop pays PKR 300,000 to supplier against outstanding balance.

| Dimension | Effect | Formula |
|-----------|--------|---------|
| Stock | 0 | — |
| Cash | − 300,000 | cash_balance −= amount_paid |
| Customer Balance | 0 | — |
| Supplier Balance | − 300,000 | supplier.outstanding −= amount_paid |
| Revenue | 0 | — |
| Profit | 0 | No profit change |

---

## 2.11 Stock Adjustment Increase

**Scenario:** During stocktake, 2 extra accessories found (previously unrecorded). Avg cost PKR 500 each.

| Dimension | Effect | Formula |
|-----------|--------|---------|
| Stock | + 2 units | qty_on_hand += 2 |
| Cash | 0 | — |
| Revenue | 0 | — |
| Inventory Gain | + 1,000 | unit_cost × qty |
| Net Profit | + 1,000 | Inventory gain increases profit |

**Accounting treatment:** Stock adjustment increase is treated as an inventory gain (credit to inventory adjustment account). It increases net profit as a non-operating gain.

---

## 2.12 Stock Adjustment Decrease

**Scenario:** Stocktake reveals 1 accessory is missing. Avg cost PKR 500.

| Dimension | Effect | Formula |
|-----------|--------|---------|
| Stock | − 1 unit | qty_on_hand −= 1 |
| Cash | 0 | — |
| Revenue | 0 | — |
| Inventory Loss | + 500 | unit_cost × qty |
| Net Profit | − 500 | Inventory loss reduces net profit |

---

## 2.13 Dealer Issue

**Scenario:** 3 phones sent to dealer. Avg cost PKR 78,333 each.

| Dimension | Effect | Formula |
|-----------|--------|---------|
| Stock (shop) | − 3 units | qty_on_hand −= 3 (moved to "with_dealer" pool) |
| Dealer Stock | + 3 units | dealer_issue.qty += 3 |
| Cash | 0 | — |
| Revenue | 0 | Not a sale |
| COGS | 0 | Not realized yet |
| Profit | 0 | Not realized yet |

---

## 2.14 Dealer Return

**Scenario:** Dealer returns 2 of the 3 phones.

| Dimension | Effect | Formula |
|-----------|--------|---------|
| Stock (shop) | + 2 units | qty_on_hand += 2 |
| Dealer Stock | − 2 units | dealer_issue.qty −= 2 |
| Cash | 0 | — |
| Revenue | 0 | — |
| Profit | 0 | — |

---

## 2.15 Dealer Issue Converted to Sale

**Scenario:** Dealer confirms purchase of the remaining 1 phone at PKR 95,000.

| Dimension | Effect | Formula |
|-----------|--------|---------|
| Stock (shop) | 0 | Already removed at issue time |
| Dealer Stock | − 1 unit | dealer_issue.qty −= 1 (closed) |
| Cash | + 95,000 (if paid) | — |
| Customer/Dealer Balance | + 0 or +outstanding | — |
| Revenue | + 95,000 | selling_price × qty |
| COGS | + 78,333 | unit_cost_at_issue × qty |
| Gross Profit | + 16,667 | revenue − COGS |

**Note:** The cost used is the WAC at the time of the original dealer issue, not the current WAC.

---

# PART 3 — PROFIT RULES

## 3.1 Definitions

### Gross Profit

```
Gross Profit = Net Sales Revenue − Cost of Goods Sold (COGS)

where:
  Net Sales Revenue = Total Sales − Sales Returns − All Discounts
  COGS = Sum of (unit_cost_at_sale × qty_sold) for all active sale items
       − Sum of (unit_cost_at_sale × qty_returned) for all returned sale items
```

**Example:**
```
Total Sales (before discount)      = PKR 500,000
Sales Returns                      = PKR  50,000
Discounts (line + invoice)         = PKR  10,000
Net Sales Revenue                  = 500,000 − 50,000 − 10,000 = PKR 440,000

Total COGS (sold items)            = PKR 350,000
COGS Reversed (returned items)     = PKR  35,000
Net COGS                           = 350,000 − 35,000 = PKR 315,000

Gross Profit = 440,000 − 315,000 = PKR 125,000
Gross Margin = 125,000 / 440,000 = 28.4%
```

---

### Net Profit

```
Net Profit = Gross Profit
           − Total Expenses
           − Total Damage Losses
           − Total Inventory Adjustment Losses
           + Total Inventory Adjustment Gains
```

**Example (continuing above):**
```
Gross Profit                       = PKR 125,000
Total Expenses                     = PKR  30,000
Total Damage Losses                = PKR  10,000
Inventory Adjustment Losses        = PKR   2,000
Inventory Adjustment Gains         = PKR   1,000

Net Profit = 125,000 − 30,000 − 10,000 − 2,000 + 1,000 = PKR 84,000
```

---

### Inventory Loss (within Net Profit)

```
Inventory Loss = Sum of (avg_cost × qty_damaged for each damage record)
               + Sum of (avg_cost × qty_lost for each stock adjustment decrease)
```

---

### Expense Impact on Profit

Expenses are period costs. They reduce net profit in the period they are incurred.

```
Expense Impact = − expense_amount
```

Expenses do NOT affect gross profit. They appear below the gross profit line.

---

### Discount Impact on Profit

Discounts reduce the selling price, therefore directly reducing both revenue and gross profit. COGS is unaffected.

```
Discount Impact = − discount_amount (applied to gross profit)
```

**Example:**
```
Item costs PKR 78,333, sells for PKR 95,000
Without discount: Gross Profit per unit = 95,000 − 78,333 = PKR 16,667
With PKR 5,000 discount: Gross Profit per unit = 90,000 − 78,333 = PKR 11,667
Discount reduced profit by PKR 5,000
```

---

### Damage Impact on Profit

Damage converts an inventory asset into a loss. The cost was already paid when purchasing. The loss materializes when damage occurs.

```
Damage Impact = − (avg_cost × qty_damaged)
```

This reduces net profit (not gross profit, as it is not a selling cost).

---

### Return Impact on Profit

**Sales Return:**  
Reverses previously recognized revenue and COGS proportionally.

```
Return Revenue Reversal = unit_price_at_sale × qty_returned − prorated_discount
Return COGS Reversal    = unit_cost_at_sale × qty_returned
Return Profit Impact    = − (Return Revenue Reversal − Return COGS Reversal)
```

If return revenue reversal > return COGS reversal, profit decreases.

**Purchase Return:**  
No immediate profit impact. Reduces cost basis (inventory asset) and reduces supplier payable.

---

# PART 4 — INVENTORY RULES

## 4.1 Stock Increase Rules

Stock increases occur due to:

| Event | Rule |
|-------|------|
| Purchase | +qty for each purchase item. Recalculate WAC. |
| Sales Return | +qty returned. WAC recalculated using `unit_cost_at_sale` as cost of returned units. |
| Dealer Return | +qty returned from dealer. WAC recalculated using original issue cost. |
| Stock Adjustment (positive) | +qty. If cost is known, use it in WAC. If unknown, use current WAC. |

**WAC Recalculation on Increase:**
```
new_avg_cost = (current_stock_value + incoming_stock_value)
               ÷ (current_qty + incoming_qty)

where:
  current_stock_value = current_qty × current_avg_cost
  incoming_stock_value = incoming_qty × incoming_unit_cost
```

---

## 4.2 Stock Decrease Rules

Stock decreases occur due to:

| Event | Rule |
|-------|------|
| Sale | −qty sold. COGS = current_avg_cost × qty. WAC unchanged. |
| Purchase Return | −qty returned to supplier. WAC unchanged. |
| Dealer Issue | −qty issued. WAC unchanged. Tracked in dealer_issue pool. |
| Damage | −qty damaged. Damage loss = current_avg_cost × qty. WAC unchanged. |
| Stock Adjustment (negative) | −qty. Inventory loss = current_avg_cost × qty. WAC unchanged. |

**Why WAC doesn't change on decrease:** WAC is a per-unit figure. Removing units doesn't change the average cost per remaining unit.

---

## 4.3 Negative Stock Policy

**Rule:** Negative stock is FORBIDDEN by default.

**Enforcement:**
- Before any stock decrease transaction (sale, damage, dealer issue, purchase return, negative adjustment), the system must verify:
  ```
  current_qty_on_hand >= qty_requested
  ```
- If this check fails, the transaction must be BLOCKED with an error message.
- Exception: The system administrator may enable a "allow negative stock" override for edge cases. This must be logged with an audit reason.

**Rationale:** Negative stock is a sign of data integrity failure. It produces mathematically incorrect COGS and inventory valuations.

---

## 4.4 Returned Stock Policy

**Sales Return Stock Handling:**
- Returned items re-enter sellable inventory.
- Condition assumed: SALEABLE (unless marked otherwise).
- If item is returned damaged (unsellable), it must be immediately recorded as a Damage, NOT returned to stock.
- WAC is recalculated using `unit_cost_at_sale` as the cost of the returned unit.

**Purchase Return Stock Handling:**
- Items are removed from inventory.
- WAC remains unchanged (per-unit average is the same before and after removal).

---

## 4.5 Damaged Stock Policy

- Damaged stock is removed from sellable inventory immediately.
- Cost of damaged stock is recorded as an inventory loss.
- Damaged stock cannot be sold; it must be recorded as Damage.
- If a damaged item is later repaired and made sellable, a positive Stock Adjustment must be created for it with an appropriate note.

---

## 4.6 Missing Stock Policy

- Missing stock discovered during stocktake is recorded as a negative Stock Adjustment.
- It creates an inventory loss equal to `avg_cost × qty_missing`.
- A reason must be provided (THEFT, MISCOUNTED, LOST, etc.).

---

## 4.7 Adjustment Policy

| Type | Stock Effect | Financial Effect |
|------|-------------|-----------------|
| Positive Adjustment | +qty | Inventory gain (+net profit) |
| Negative Adjustment | −qty | Inventory loss (−net profit) |
| Correction Adjustment | Bring to exact count | Net difference treated as above |

**Audit trail:** Every adjustment must be logged with date, product, qty, reason, and the user who made it.

---

# PART 5 — RETURN RULES

## 5.1 Sales Return Logic

### 5.1.1 Full Return

**Rule:** All items from a sale are returned.

**Stock:** All quantities restored to inventory.  
**Revenue:** Reversed in full = grand_total of original sale.  
**COGS:** Reversed in full = sum of all (unit_cost_at_sale × qty).  
**Profit:** Net reversal = (revenue_reversed − COGS_reversed), applied as negative.  
**Customer Balance:** Reduced by return value. Refund or credit note issued.

**Example:**
```
Original Sale:
  2 iPhones × PKR 95,000 = PKR 190,000
  Invoice Discount: PKR 10,000
  Grand Total: PKR 180,000
  Paid: PKR 180,000 (cash)
  COGS: 2 × PKR 78,333 = PKR 156,666

Full Return:
  Revenue Reversed: PKR 180,000
  COGS Reversed: PKR 156,666
  Gross Profit Impact: −(180,000 − 156,666) = −PKR 23,334
  Cash Refunded: PKR 180,000
  Stock Restored: +2 units
```

---

### 5.1.2 Partial Return

**Rule:** Only some items are returned.

**Stock:** Only returned quantities restored.  
**Revenue Reversed:** Prorated to the items returned.  

**Prorating Discount to Returned Items:**
```
discount_per_item = invoice_discount / total_items_in_sale

For a partial return of item X:
  item_revenue = (unit_price × qty_returned_of_X) − (line_discount_of_X per unit × qty_returned)
  prorated_invoice_discount = (qty_returned_of_X / total_qty_in_sale) × invoice_discount
  net_return_revenue = item_revenue − prorated_invoice_discount
```

**Example:**
```
Sale: 2 iPhones + 1 Case
  iPhone: 2 × 95,000 = 190,000
  Case: 1 × 2,000 = 2,000
  Invoice Discount: 9,200
  Grand Total: 182,800
  Total items: 3

Customer returns 1 iPhone only.

  Prorated invoice discount for 1 iPhone:
    (1/3) × 9,200 = PKR 3,066.67

  Return Revenue: 95,000 − 3,066.67 = PKR 91,933.33
  Return COGS: PKR 78,333
  Gross Profit Impact: −(91,933 − 78,333) = −PKR 13,600
  Stock: +1 iPhone
```

---

### 5.1.3 Return After Discount

**Rule:** When a sale had a discount, the discount must be prorated proportionally to the returned items. The customer does not receive back more than what they paid for those items.

**Formula:**
```
effective_unit_price = (grand_total / total_qty) for uniform items
                     OR prorated as shown in 5.1.2 for mixed items
```

**Policy:** Refund is based on effective price paid, NOT original list price.

---

### 5.1.4 Return After Multiple Payments

**Scenario:** Customer bought on credit, made partial payments, now returns item.

**Rule:**
1. Determine the return value (prorated revenue as above).
2. Reduce customer balance by return value.
3. If customer has overpaid relative to remaining balance, the excess is a cash refund or credit note.

**Example:**
```
Sale: PKR 90,000 (2 items)
Customer paid: PKR 50,000 cash
Outstanding: PKR 40,000

Customer returns 1 item (value: PKR 45,000)

Customer balance before return: PKR 40,000 (owes us)
Return value: PKR 45,000

New balance = 40,000 − 45,000 = −PKR 5,000 (we owe customer)

Resolution: Refund PKR 5,000 to customer in cash. Customer balance = 0.
```

---

## 5.2 Purchase Return Logic

### 5.2.1 Full Purchase Return

**Rule:** All items returned to supplier.

**Stock:** All quantities removed from inventory.  
**Supplier Balance:** Reduced by total return value.  
**Cash:** If supplier refunds cash, cash_balance increases.  
**COGS Basis:** Reduced (inventory value decreases).  
**Profit:** No direct impact.

---

### 5.2.2 Partial Purchase Return

**Rule:** Only some items returned.

**Stock:** Only returned quantities removed.  
**Supplier Balance:** Reduced by value of returned items only.  
**WAC:** Unchanged after removal.

---

# PART 6 — DISCOUNT RULES

## 6.1 Line Item Discount

**Definition:** A discount applied to a specific product line within a sale.

**Formula:**
```
line_total = (unit_price × quantity) − line_discount
```

**Example:**
```
Unit Price: PKR 95,000
Qty: 2
Line Discount: PKR 5,000
Line Total: (95,000 × 2) − 5,000 = PKR 185,000
```

---

## 6.2 Invoice Discount

**Definition:** A discount applied to the total sale after summing all line items.

**Formula:**
```
subtotal = sum of all line_totals
grand_total = subtotal − invoice_discount
```

**Example:**
```
Subtotal: PKR 190,000 (after line discounts)
Invoice Discount: PKR 10,000
Grand Total: PKR 180,000
```

**Priority:** Invoice discount is applied AFTER line discounts. Both reduce revenue.

---

## 6.3 Percentage Discount

**Definition:** Discount expressed as a percentage of the line or invoice total.

**Formula:**
```
discount_amount = base_amount × (discount_pct / 100)
```

**Example:**
```
Line Total before discount: PKR 100,000
Discount: 5%
Discount Amount: PKR 5,000
Final Line Total: PKR 95,000
```

**Rule:** Convert percentage discounts to fixed amounts at transaction time. Store the fixed amount. Never store only the percentage — prices may change.

---

## 6.4 Does Discount Reduce Revenue?

**YES.** Discounts reduce revenue directly.

```
Net Revenue = Selling Price × Qty − All Discounts
```

---

## 6.5 Does Discount Reduce Profit?

**YES.** Since revenue decreases and COGS stays the same, profit decreases by the exact discount amount.

```
Gross Profit = Net Revenue − COGS
             = (Selling Price × Qty − Discount) − COGS
```

---

## 6.6 Does Discount Affect Stock?

**NO.** Discounts have no effect on stock quantity or inventory value.

---

## 6.7 Combined Discount Formula

```
Total Discount = Sum of line_discounts + invoice_discount
Net Revenue = Gross Selling Price − Total Discount
Gross Profit = Net Revenue − COGS
Discount's effect on profit = −Total Discount
```

---

# PART 7 — DAMAGE RULES

## 7.1 Damage Categories

| Category | Description |
|----------|------------|
| BROKEN | Physical damage (cracked screen, bent frame) |
| THEFT | Stolen from shop |
| LOST | Cannot be located — presumed lost |
| WATER_DAMAGE | Liquid damage |
| OTHER | Any other reason |

---

## 7.2 Damaged Before Sale (Pre-Sale Damage)

**Rule:** Item was in inventory and became damaged before being sold.

**Stock Effect:** −qty_damaged  
**Financial Effect:** Damage Loss = avg_cost × qty_damaged  
**Revenue Effect:** 0 (item was never sold)  
**Profit Effect:** −damage_loss (reduces net profit)

**Example:**
```
1 iPhone (avg_cost = PKR 78,333) dropped and cracked.
Stock: −1 unit (qty_on_hand decreases)
Damage Loss: PKR 78,333
Net Profit Impact: −PKR 78,333
Revenue Impact: 0
COGS Impact: 0 (damage loss is separate from COGS)
```

---

## 7.3 Damaged After Purchase (Same Day)

Treated identically to 7.2. The purchase records the acquisition; the damage records the loss. Both transactions exist in the system.

---

## 7.4 Lost Inventory

**Rule:** Applies when items cannot be physically located.

Treated as a negative Stock Adjustment with reason = LOST or as a Damage record.

**Policy choice:** Use Damage record (not stock adjustment) when the loss is definitive and no future recovery is expected. Use Stock Adjustment when investigating — the adjustment can be reversed if stock is found.

---

## 7.5 Broken Accessory

Same rules as 7.2. The only difference is the product category (ACCESSORY vs PHONE). Financial treatment is identical.

---

## 7.6 Revenue Effect of Damage

**0.** A damaged item generates no revenue.

---

## 7.7 Cost Effect of Damage

**+damage_loss** is recognized (as an expense/loss).

The cost was already embedded in inventory value. Damage converts inventory asset to an expense.

---

## 7.8 Profit Effect of Damage

```
Profit Effect = − (avg_cost × qty_damaged)
```

This reduces net profit (below the gross profit line, in the "other losses" section).

---

## 7.9 Stock Effect of Damage

```
qty_on_hand = qty_on_hand − qty_damaged
```

WAC does not change.

---

# PART 8 — DEALER ISSUE RULES

## 8.1 Business Context

A dealer is a person or business to whom stock is physically given on a trial/consignment basis. The shop does NOT receive payment at the time of issue. The outcome can be:

1. Dealer returns all items → no financial event
2. Dealer buys some items → those become a sale
3. Items are lost/damaged with dealer → those become a damage loss

---

## 8.2 Stock Rules for Dealer Issues

| Event | Stock Rule |
|-------|-----------|
| Dealer Issue | qty_on_hand −= qty_issued; qty_with_dealer += qty_issued |
| Dealer Return | qty_on_hand += qty_returned; qty_with_dealer −= qty_returned |
| Dealer Sale (conversion) | qty_with_dealer −= qty_sold; no change to qty_on_hand |
| Dealer Loss | qty_with_dealer −= qty_lost; Damage record created |

**Two stock pools exist:**
- `qty_on_hand` — in shop, available for sale
- `qty_with_dealer` — with dealer, not available for sale to other customers

---

## 8.3 Financial Rules for Dealer Issues

### At time of issue:
- **No revenue recognized.** (No sale has occurred.)
- **No COGS recognized.** (Ownership has not transferred.)
- **No profit.**
- **No cash flow.**
- **Customer/dealer balance: 0.** (No obligation yet.)

### At time of Dealer Return (partial or full):
- No financial effect. Stock just comes back.

### At time of Dealer Sale Conversion:
- Revenue recognized = selling_price × qty_sold
- COGS recognized = unit_cost_at_issue × qty_sold
- Gross Profit = Revenue − COGS
- Customer/Dealer balance increases by amount not paid immediately.
- Cash increases by amount paid immediately.

### At time of Dealer Loss:
- Damage Loss = avg_cost × qty_lost
- Net Profit impact: −damage_loss
- Stock pool (with_dealer) decreases.

---

## 8.4 Does Dealer Issue Immediately Affect Profit?

**NO.**

**Reasoning:**
- Revenue recognition principle: revenue is recognized when earned (when the customer buys, not when stock is handed over on trial).
- If dealer issue immediately affected profit, the profit would be negative (COGS would be recognized with no corresponding revenue), which is financially incorrect.
- The profit is deferred until the outcome is known.

---

## 8.5 Dealer Issue vs. Sale — Key Distinction

| Criterion | Dealer Issue | Sale |
|-----------|-------------|------|
| Revenue | Not recognized | Recognized immediately |
| COGS | Not recognized | Recognized immediately |
| Stock change | Moves to "with_dealer" pool | Leaves inventory entirely |
| Customer obligation | None yet | Immediate |
| Profit | Not yet realized | Realized |

---

# PART 9 — REPORTING RULES

## 9.1 Total Sales

```
Total Sales = Sum of grand_total for all ACTIVE sales
            (i.e., sales not fully deleted)
```

This is the gross sales figure before deducting returns.

---

## 9.2 Net Sales

```
Net Sales = Total Sales − Total Sales Returns (value of returned items)
```

Where:
```
Total Sales Returns = Sum of return_value for all sales return records
```

Net Sales represents actual revenue earned after accounting for returns.

---

## 9.3 Total Purchases

```
Total Purchases = Sum of grand_total for all ACTIVE purchases
```

---

## 9.4 Net Purchases

```
Net Purchases = Total Purchases − Total Purchase Returns (value of returned items)
```

---

## 9.5 Gross Profit

```
Gross Profit = Net Sales − Net COGS

where:
  Net COGS = Total COGS of sold items − COGS reversed by sales returns
  Total COGS = Sum of (unit_cost_at_sale × qty_sold) across all active sale items
  COGS Reversed = Sum of (unit_cost_at_sale × qty_returned) across all return items
```

---

## 9.6 Net Profit

```
Net Profit = Gross Profit
           − Total Expenses
           − Total Damage Losses
           − Total Inventory Adjustment Losses
           + Total Inventory Adjustment Gains
```

---

## 9.7 Total Expenses

```
Total Expenses = Sum of amount for all active expense records in the period
```

---

## 9.8 Total Damages

```
Total Damages = Sum of (unit_cost × qty) for all damage records in the period
```

---

## 9.9 Inventory Value

```
Inventory Value = Sum of (qty_on_hand × avg_cost) for each product
```

This represents the total cost of stock currently held in the shop (excluding stock with dealers).

```
Total Inventory Including Dealer Stock = Inventory Value + Dealer Stock Value

Dealer Stock Value = Sum of (qty_with_dealer × unit_cost_at_issue) for each product
```

---

## 9.10 Outstanding Receivables (Customer Balances)

```
Outstanding Receivables = Sum of outstanding_balance for all customers
                          where outstanding_balance > 0
```

This is money owed TO the shop by customers.

---

## 9.11 Outstanding Payables (Supplier Balances)

```
Outstanding Payables = Sum of outstanding_balance for all suppliers
                       where outstanding_balance > 0
```

This is money owed BY the shop to suppliers.

---

## 9.12 Cash Position

```
Cash Balance = Opening Balance
             + All cash inflows (cash sales, customer payments, supplier refunds, positive adjustments)
             − All cash outflows (cash purchases, supplier payments, customer refunds, expenses)
```

---

## 9.13 Period Filtering

All reports must support filtering by date range. The date used for filtering is the `transaction_date` of each record.

---

# PART 10 — EDGE CASES

## 10.1 Sale Deleted

**Rule:** Deleting a sale is a full reversal of all effects.

| Effect | Action |
|--------|--------|
| Stock | Restore all quantities (+qty for each sale item) |
| Revenue | Reverse all revenue (−grand_total) |
| COGS | Reverse all COGS |
| Cash | If cash was received: −cash_received (reduce cash balance) |
| Customer Balance | If credit: −balance_due |
| Associated returns | Block deletion if returns exist against this sale. Returns must be deleted first, OR the sale can be soft-deleted with a DELETED flag and all associated returns also invalidated. |

**Policy:** Sales with partial/full returns cannot be deleted until all return records are deleted first.

---

## 10.2 Purchase Deleted

| Effect | Action |
|--------|--------|
| Stock | Reverse all quantities (−qty for each purchase item) |
| WAC | Recalculate WAC after removal |
| Cash | If cash was paid: +cash_paid (restore cash balance) |
| Supplier Balance | If credit: −balance_due |
| Block condition | Block if stock has already been sold (selling price > 0 items from this purchase already in COGS chain). Warn user. |

**Policy:** The system must check if any units from this purchase lot have been sold. If so, deletion may corrupt COGS. A warning must be shown; forced deletion should only be allowed with admin override.

---

## 10.3 Return Deleted

**Sales Return Deleted:**

| Effect | Action |
|--------|--------|
| Stock | Reverse the return: −qty (remove the returned stock that was added) |
| Revenue | Re-recognize the revenue that was reversed |
| COGS | Re-recognize the COGS that was reversed |
| Customer Balance | Restore the balance that was reduced |
| Cash | If refund was made: reverse refund (add cash back) |

**Purchase Return Deleted:**

| Effect | Action |
|--------|--------|
| Stock | Re-add the returned stock +qty |
| WAC | Recalculate |
| Supplier Balance | Restore supplier balance |
| Cash | If refund was received: subtract cash |

---

## 10.4 Expense Deleted

| Effect | Action |
|--------|--------|
| Cash | +expense_amount (restore cash) |
| Net Profit | +expense_amount (profit increases) |

---

## 10.5 Damage Deleted

| Effect | Action |
|--------|--------|
| Stock | +qty (restore inventory) |
| WAC | Recalculate |
| Net Profit | +damage_loss_amount (profit increases) |

---

## 10.6 Edited Sale

**Rule:** Editing a sale is treated as: DELETE old sale effects + APPLY new sale effects.

**Process:**
1. Compute the difference between old and new values.
2. Reverse old stock, revenue, COGS, cash, customer balance impacts.
3. Apply new stock, revenue, COGS, cash, customer balance impacts.
4. WAC recalculates for any changed quantities.

**Constraint:** If a sales return exists against this sale, editing must respect the returned quantities (cannot reduce sold qty below already-returned qty).

---

## 10.7 Edited Purchase

**Process:**
1. Reverse old stock and supplier balance.
2. Recalculate WAC backwards (remove old purchase contribution).
3. Apply new purchase values.
4. Recalculate WAC forward.

**Constraint:** If items from this purchase have already been sold, editing quantity down below sold quantity is forbidden. The system must validate this.

---

## 10.8 Edited Return

**Process:**
1. Reverse effects of the old return.
2. Apply effects of the new return.
3. Validate that new return quantities do not exceed original sale quantities.

---

## 10.9 General Rule for All Edits and Deletions

> **The system must always be in a state where:**
> ```
> Inventory Value = Sum of all purchases (at cost)
>                 − Sum of all COGS (at cost)
>                 − Sum of all purchase returns (at cost)
>                 − Sum of all damage losses (at cost)
>                 − Sum of all negative adjustments (at cost)
>                 + Sum of all positive adjustments (at cost)
>                 + Sum of all sales return restorations (at cost)
> ```

Any edit or deletion must maintain this invariant.

---

# PART 11 — TEST SCENARIOS (50+)

The following scenarios use PKR as currency.

---

## PURCHASE SCENARIOS

### S-01: Simple Cash Purchase
**Input:** Buy 5 iPhones at PKR 80,000 each. Pay PKR 400,000 cash.  
**Stock:** +5 units  
**Cash:** −400,000  
**Supplier Balance:** 0  
**COGS Basis:** +400,000 (inventory value)  
**Profit:** 0

---

### S-02: Credit Purchase
**Input:** Buy 3 iPhones at PKR 80,000 each. Pay PKR 100,000, rest on credit.  
**Stock:** +3 units  
**Cash:** −100,000  
**Supplier Balance:** +140,000  
**COGS Basis:** +240,000  
**Profit:** 0

---

### S-03: Purchase + WAC Update
**Input:** Existing: 5 units at avg_cost PKR 75,000. New purchase: 5 units at PKR 85,000.  
**Stock:** +5 = 10 total  
**WAC:** (5×75,000 + 5×85,000) / 10 = PKR 80,000  
**Cash:** −425,000 (assuming cash)  
**Profit:** 0

---

### S-04: Full Purchase Return (Cash)
**Input:** Return 3 iPhones at PKR 80,000 avg_cost. Supplier refunds cash.  
**Stock:** −3 units  
**Cash:** +240,000  
**Supplier Balance:** −240,000  
**WAC:** Unchanged  
**Profit:** 0

---

### S-05: Partial Purchase Return (Credit Adjustment)
**Input:** Return 1 iPhone of 3 purchased at PKR 80,000. Supplier credits account.  
**Stock:** −1 unit  
**Cash:** 0  
**Supplier Balance:** −80,000  
**Profit:** 0

---

## SALE SCENARIOS

### S-06: Simple Cash Sale
**Input:** Sell 2 iPhones at PKR 95,000 each. Cash payment. WAC = PKR 80,000.  
**Stock:** −2 units  
**Cash:** +190,000  
**Revenue:** +190,000  
**COGS:** +160,000  
**Gross Profit:** +30,000  
**Customer Balance:** 0

---

### S-07: Credit Sale
**Input:** Sell 1 iPhone at PKR 95,000. No payment. WAC = PKR 80,000.  
**Stock:** −1 unit  
**Cash:** 0  
**Revenue:** +95,000  
**COGS:** +80,000  
**Gross Profit:** +15,000  
**Customer Balance:** +95,000

---

### S-08: Partial Payment Sale
**Input:** Sell 2 iPhones at PKR 95,000 each. Customer pays PKR 100,000.  
**Stock:** −2 units  
**Cash:** +100,000  
**Revenue:** +190,000  
**COGS:** +160,000  
**Gross Profit:** +30,000  
**Customer Balance:** +90,000

---

### S-09: Sale With Line Discount
**Input:** Sell 1 iPhone at PKR 95,000, line discount PKR 5,000. Cash payment. WAC = PKR 80,000.  
**Stock:** −1  
**Cash:** +90,000  
**Revenue:** +90,000  
**COGS:** +80,000  
**Gross Profit:** +10,000

---

### S-10: Sale With Invoice Discount
**Input:** Sell 2 iPhones at PKR 95,000 each, invoice discount PKR 10,000. Cash. WAC = PKR 80,000.  
**Stock:** −2  
**Cash:** +180,000  
**Revenue:** +180,000  
**COGS:** +160,000  
**Gross Profit:** +20,000

---

### S-11: Sale With Both Line and Invoice Discount
**Input:** Sell 2 iPhones at PKR 95,000 each. Line discount PKR 2,000 per phone. Invoice discount PKR 5,000. WAC = PKR 80,000.  
**Subtotal:** (95,000−2,000)×2 = 186,000  
**Grand Total:** 186,000 − 5,000 = 181,000  
**Stock:** −2  
**Revenue:** +181,000  
**COGS:** +160,000  
**Gross Profit:** +21,000

---

### S-12: Mixed Product Sale (Phone + Accessory)
**Input:** Sell 1 iPhone (PKR 95,000, WAC 80,000) + 2 Cases (PKR 2,000 each, WAC 500 each). Cash.  
**Stock:** iPhone −1, Case −2  
**Revenue:** 95,000 + 4,000 = 99,000  
**COGS:** 80,000 + 1,000 = 81,000  
**Gross Profit:** +18,000

---

## SALES RETURN SCENARIOS

### S-13: Full Sales Return (Cash Refund)
**Input:** Return all items from S-06 (2 iPhones, revenue was PKR 190,000, COGS 160,000). Refund in cash.  
**Stock:** +2 units (WAC recalculates using PKR 80,000 cost)  
**Cash:** −190,000  
**Revenue:** −190,000  
**COGS:** −160,000  
**Gross Profit:** −30,000  
**Customer Balance:** 0 (no change, it was 0)

---

### S-14: Partial Sales Return (1 of 2 items)
**Input:** From S-06, customer returns 1 iPhone. No invoice discount existed. Refund cash.  
**Stock:** +1 unit  
**Cash:** −95,000  
**Revenue:** −95,000  
**COGS:** −80,000  
**Gross Profit:** −15,000

---

### S-15: Sales Return With Invoice Discount Prorating
**Input:** From S-10 (2 iPhones, invoice discount PKR 10,000, grand total PKR 180,000). Customer returns 1 iPhone.  
**Prorated discount for 1 unit:** 10,000/2 = PKR 5,000  
**Return Revenue:** 95,000 − 5,000 = PKR 90,000  
**Stock:** +1 unit  
**Cash:** −90,000 (assuming refund)  
**Revenue:** −90,000  
**COGS:** −80,000  
**Gross Profit:** −10,000

---

### S-16: Sales Return After Partial Payment (Customer Has Balance)
**Input:** Sale PKR 190,000, customer paid PKR 100,000 (balance PKR 90,000). Returns 1 item worth PKR 90,000 (post-discount).  
**Customer balance before:** +90,000  
**Return value:** 90,000  
**Customer balance after:** 90,000 − 90,000 = 0  
**Cash:** 0 (balance cleared, no refund needed)  
**Revenue:** −90,000  
**COGS:** −80,000  
**Gross Profit:** −10,000

---

### S-17: Sales Return — Overpayment → Cash Refund
**Input:** Sale PKR 95,000, customer paid full PKR 95,000. Returns item worth PKR 95,000.  
**Customer balance before:** 0  
**Return value:** 95,000  
**We owe customer:** PKR 95,000  
**Cash Refunded:** −95,000  
**Revenue:** −95,000  
**COGS:** −80,000  
**Gross Profit:** −15,000

---

## EXPENSE SCENARIOS

### S-18: Rent Expense
**Input:** Pay PKR 20,000 rent in cash.  
**Stock:** 0  
**Cash:** −20,000  
**Revenue:** 0  
**Gross Profit:** 0  
**Net Profit:** −20,000

---

### S-19: Salary Expense
**Input:** Pay PKR 15,000 salary.  
**Net Profit:** −15,000  
**Cash:** −15,000

---

### S-20: Transport Expense
**Input:** PKR 1,500 transport paid.  
**Net Profit:** −1,500  
**Cash:** −1,500

---

## DAMAGE SCENARIOS

### S-21: Phone Damaged (Broken)
**Input:** 1 iPhone damaged. WAC = PKR 80,000.  
**Stock:** −1 unit  
**Revenue:** 0  
**Damage Loss:** +80,000  
**Net Profit:** −80,000

---

### S-22: Accessory Damaged
**Input:** 2 Cases damaged. WAC = PKR 500 each.  
**Stock:** −2 units (Cases)  
**Damage Loss:** +1,000  
**Net Profit:** −1,000

---

### S-23: Theft
**Input:** 1 iPhone stolen. WAC = PKR 80,000. Reason = THEFT.  
**Stock:** −1  
**Damage Loss:** +80,000  
**Net Profit:** −80,000

---

## DEALER ISSUE SCENARIOS

### S-24: Dealer Issue (No Outcome Yet)
**Input:** Issue 2 iPhones to dealer. WAC = PKR 80,000.  
**Shop Stock:** −2  
**Dealer Stock:** +2  
**Revenue:** 0  
**Profit:** 0  
**Cash:** 0

---

### S-25: Full Dealer Return
**Input:** Dealer returns both 2 iPhones from S-24.  
**Shop Stock:** +2  
**Dealer Stock:** −2  
**Revenue:** 0  
**Profit:** 0

---

### S-26: Partial Dealer Return + Partial Sale
**Input:** From S-24, dealer returns 1 iPhone and buys 1 at PKR 95,000.  
**Dealer Return:** Shop Stock +1, Dealer Stock −1, no financial impact.  
**Dealer Sale:**  
  - Revenue: +95,000  
  - COGS: +80,000  
  - Gross Profit: +15,000  
  - Cash: +95,000 (if paid)

---

### S-27: Dealer Issue → Item Lost
**Input:** From S-24, dealer reports 1 iPhone lost.  
**Dealer Stock:** −1  
**Damage Record:** +80,000 loss  
**Net Profit:** −80,000

---

## CUSTOMER BALANCE SCENARIOS

### S-28: Cash Received from Customer
**Input:** Customer pays PKR 90,000 outstanding balance.  
**Cash:** +90,000  
**Customer Balance:** −90,000  
**Profit:** 0 (settlement, not new revenue)

---

### S-29: Customer Overpayment
**Input:** Customer balance is PKR 10,000. Customer pays PKR 15,000.  
**Cash:** +15,000  
**Customer Balance:** 10,000 − 15,000 = −5,000 (we owe customer PKR 5,000)  
**Profit:** 0

---

## SUPPLIER BALANCE SCENARIOS

### S-30: Cash Paid to Supplier
**Input:** Pay supplier PKR 140,000 outstanding balance.  
**Cash:** −140,000  
**Supplier Balance:** −140,000  
**Profit:** 0

---

### S-31: Supplier Overpayment
**Input:** Supplier balance PKR 50,000. Shop pays PKR 60,000.  
**Cash:** −60,000  
**Supplier Balance:** −10,000 (supplier owes shop PKR 10,000)  
**Profit:** 0

---

## STOCK ADJUSTMENT SCENARIOS

### S-32: Positive Stock Adjustment
**Input:** Stocktake finds 3 extra Cases (WAC = PKR 500 each).  
**Stock:** +3 Cases  
**Inventory Gain:** +1,500  
**Net Profit:** +1,500  
**Cash:** 0

---

### S-33: Negative Stock Adjustment (Missing Items)
**Input:** Stocktake shows 2 Cases missing (WAC = PKR 500 each).  
**Stock:** −2 Cases  
**Inventory Loss:** +1,000  
**Net Profit:** −1,000  
**Cash:** 0

---

## COMBINED SCENARIOS

### S-34: Full Business Cycle (Purchase → Sale → Return)
**Input:**  
Step 1: Buy 5 iPhones at PKR 80,000 each (cash). Stock: 5, WAC: 80,000, Cash: −400,000  
Step 2: Sell 3 iPhones at PKR 95,000 each (cash). Stock: 2, Cash: +285,000, Revenue: +285,000, COGS: +240,000, GP: +45,000  
Step 3: Customer returns 1 iPhone. Refund PKR 95,000 cash. Stock: 3, Cash: −95,000, Revenue: −95,000, COGS: −80,000, GP: −15,000

**Final State:**  
Stock: 3 iPhones, WAC: PKR 80,000  
Net Cash: −400,000 + 285,000 − 95,000 = −210,000  
Net Revenue: 285,000 − 95,000 = 190,000  
Net COGS: 240,000 − 80,000 = 160,000  
Gross Profit: 190,000 − 160,000 = PKR 30,000

---

### S-35: Sale + Expense Impact on Net Profit
**Input:**  
Sale: 1 iPhone at PKR 95,000 (WAC 80,000). GP: +15,000  
Expense: PKR 5,000 (rent)  
**Net Profit:** 15,000 − 5,000 = PKR 10,000

---

### S-36: Sale + Damage Impact on Net Profit
**Input:**  
Sale: 1 iPhone at PKR 95,000 (WAC 80,000). GP: +15,000  
Damage: 1 iPhone (WAC 80,000)  
**Gross Profit:** 15,000  
**Net Profit:** 15,000 − 80,000 = −PKR 65,000 (loss)

---

### S-37: Multiple Purchases Updating WAC
**Input:**  
Purchase 1: 10 units at PKR 70,000. WAC: 70,000  
Purchase 2: 5 units at PKR 80,000. WAC: (10×70,000 + 5×80,000)/15 = (700,000+400,000)/15 = PKR 73,333  
Purchase 3: 5 units at PKR 90,000. WAC: (15×73,333 + 5×90,000)/20 = (1,099,995+450,000)/20 = PKR 77,500

**Sale COGS:** Unit sold at current WAC = PKR 77,500

---

### S-38: Sale With Percentage Discount
**Input:** Sell 2 iPhones at PKR 95,000. 10% invoice discount. WAC = PKR 80,000.  
Invoice total: 190,000  
10% discount: 19,000  
Grand Total: 171,000  
COGS: 160,000  
**Gross Profit:** 171,000 − 160,000 = PKR 11,000

---

### S-39: Credit Sale + Customer Payment + Return (Complex)
**Input:**  
Sale: 3 iPhones at PKR 95,000. Grand Total PKR 285,000. Customer pays PKR 100,000. Balance PKR 185,000.  
Customer pays PKR 85,000 more. Balance: PKR 100,000.  
Customer returns 1 iPhone (value PKR 95,000).  
  Customer Balance: 100,000 − 95,000 = PKR 5,000.  
**Final State:**  
Revenue: 285,000 − 95,000 = 190,000  
COGS: 240,000 − 80,000 = 160,000  
GP: 30,000  
Customer Balance: 5,000 (still owes PKR 5,000)  
Cash Received: 185,000

---

### S-40: Dealer Issue Fully Converted to Sale
**Input:**  
Issue: 5 iPhones to dealer. WAC = PKR 80,000.  
Dealer buys all 5 at PKR 95,000 each. Cash.  
**Revenue:** +475,000  
**COGS:** +400,000  
**Gross Profit:** +75,000  
**Cash:** +475,000  
**Shop Stock:** unchanged (already removed at issue)  
**Dealer Stock:** 0

---

### S-41: Deletion of Sale — Financial Reversal
**Input:**  
Sale was: 2 iPhones at PKR 95,000, cash, no discount. GP = 30,000.  
Delete sale.  
**Stock:** +2 (restored)  
**Cash:** −190,000 (reversed)  
**Revenue:** −190,000  
**COGS:** −160,000  
**Gross Profit:** −30,000  
**Net effect:** As if sale never happened.

---

### S-42: Delete Expense — Financial Reversal
**Input:**  
Expense PKR 20,000 deleted.  
**Cash:** +20,000  
**Net Profit:** +20,000

---

### S-43: Delete Damage Record — Financial Reversal
**Input:**  
Damage: 1 iPhone, PKR 80,000 deleted.  
**Stock:** +1 iPhone  
**Net Profit:** +80,000  
**Damage Loss:** −80,000

---

### S-44: Edit Sale — Price Changed
**Input:**  
Original: 1 iPhone at PKR 95,000. Edited to PKR 90,000.  
**Revenue diff:** −5,000  
**Gross Profit diff:** −5,000  
**Customer Balance diff:** −5,000 (if credit)  
**COGS:** unchanged

---

### S-45: Selling Below Cost (Loss Sale)
**Input:** Sell 1 iPhone at PKR 75,000. WAC = PKR 80,000.  
**Revenue:** +75,000  
**COGS:** +80,000  
**Gross Profit:** −5,000 (loss on this sale)  
**Note:** System must allow this but may show a warning. It is a valid business scenario (clearance sale).

---

### S-46: Zero Discount Sale Verification
**Input:** Sell 1 iPhone at PKR 95,000, no discount. Cash. WAC = PKR 80,000.  
**Revenue:** 95,000  
**COGS:** 80,000  
**GP:** 15,000  
**Total Discount:** 0  
**Cash:** +95,000

---

### S-47: Return on Previously Discounted Sale — Correct Prorating
**Input:**  
Sale: 3 iPhones at PKR 95,000 each. Invoice Discount: PKR 15,000.  
Grand Total: 285,000 − 15,000 = 270,000.  
Customer returns 1 iPhone.  
Prorated discount: 15,000/3 = PKR 5,000.  
Return Revenue: 95,000 − 5,000 = PKR 90,000.  
**Refund:** PKR 90,000  
**Revenue reversed:** 90,000  
**COGS reversed:** 80,000  
**GP Impact:** −10,000

---

### S-48: Multiple Returns Against Same Sale
**Input:**  
Sale: 3 iPhones. Customer returns 1 (Return #1). Later returns another (Return #2).  
**Return #1:** Stock +1, Revenue −X, COGS −Y  
**Return #2:** Stock +1, Revenue −X, COGS −Y  
**Validation:** Total returned (2) must not exceed total sold (3). System must enforce this.  
**Remaining:** 1 item still sold.

---

### S-49: Stock Adjustment Then Sale
**Input:**  
Current stock: 5 iPhones, WAC PKR 80,000.  
Positive adjustment: +2 units at PKR 80,000 (found in stock). WAC: still PKR 80,000.  
Sell 6 iPhones at PKR 95,000.  
**Stock after:** 5+2−6 = 1 unit  
**Revenue:** +570,000  
**COGS:** 6 × 80,000 = 480,000  
**GP:** 90,000

---

### S-50: Comprehensive Net Profit Calculation
**Input (period summary):**  
Total Sales: PKR 1,000,000  
Sales Returns: PKR 50,000  
Total Discounts: PKR 30,000  
Net Sales: 1,000,000 − 50,000 − 30,000 = PKR 920,000  
Total COGS: PKR 700,000  
COGS from Returns: PKR 35,000  
Net COGS: 700,000 − 35,000 = PKR 665,000  
Gross Profit: 920,000 − 665,000 = PKR 255,000  
Total Expenses: PKR 80,000  
Total Damage Losses: PKR 20,000  
Inventory Adjustment Losses: PKR 5,000  
Inventory Adjustment Gains: PKR 2,000  
**Net Profit:** 255,000 − 80,000 − 20,000 − 5,000 + 2,000 = **PKR 152,000**

---

### S-51: Zero-Cost Stock Adjustment Then Sale (Edge Case)
**Input:**  
Found item with unknown cost. Record positive adjustment with cost = PKR 0.  
Sell item at PKR 2,000.  
**Revenue:** +2,000  
**COGS:** 0 (cost was 0)  
**GP:** +2,000  
**Note:** System must allow cost = 0 but should flag it for review.

---

### S-52: Purchase Return → Then Sale of Remaining Stock
**Input:**  
Buy 10 accessories at PKR 500 each. WAC: 500.  
Return 3 to supplier. Stock: 7 at WAC 500.  
Sell 4 at PKR 800 each.  
**Revenue:** +3,200  
**COGS:** 4 × 500 = 2,000  
**GP:** +1,200  
**Remaining stock:** 3 units

---

### S-53: Full Inventory Liquidation (All Stock Sold)
**Input:**  
Stock: 5 iPhones, WAC PKR 80,000. Sell all 5 at PKR 90,000.  
**Stock after:** 0  
**Revenue:** 450,000  
**COGS:** 400,000  
**GP:** 50,000  
**Note:** Stock can reach 0 but must not go negative.

---

### S-54: Blocked Negative Stock Scenario
**Input:**  
Stock: 2 iPhones. Attempt to sell 3.  
**Result:** Transaction BLOCKED. Error: "Insufficient stock. Available: 2, Requested: 3."  
**Stock:** Unchanged at 2  
**Revenue:** 0  
**Profit:** 0

---

### S-55: Cash Balance Reconciliation
**Input (daily summary):**  
Opening Cash: PKR 50,000  
Cash Sales: PKR 200,000  
Cash from Customer Payments: PKR 30,000  
Cash Expenses: PKR 15,000  
Cash Purchases: PKR 100,000  
Cash Refunds to Customers: PKR 10,000  
**Expected Cash Balance:** 50,000 + 200,000 + 30,000 − 15,000 − 100,000 − 10,000 = **PKR 155,000**

---

### S-56: Dealer Issue + Loss + Partial Sale (Complex)
**Input:**  
Issue 4 phones to dealer (WAC PKR 80,000 each). Dealer stock: 4.  
Dealer returns 1: Shop stock +1, Dealer stock: 3.  
Dealer loses 1: Damage loss PKR 80,000, Dealer stock: 2.  
Dealer buys 2 at PKR 95,000 each: Revenue +190,000, COGS +160,000, GP +30,000.  
**Net Profit from this dealer:** 30,000 − 80,000 = −PKR 50,000 (net loss due to damage)

---

### S-57: Multiple Suppliers + Separate Balances
**Input:**  
Buy from Supplier A: PKR 500,000. Pay PKR 200,000. Balance: PKR 300,000.  
Buy from Supplier B: PKR 300,000. Pay PKR 300,000. Balance: PKR 0.  
**Total Outstanding Payables:** PKR 300,000 (only Supplier A)

---

### S-58: Multiple Customers + Receivables
**Input:**  
Customer A: Total purchases PKR 100,000. Paid PKR 80,000. Balance: PKR 20,000.  
Customer B: Total purchases PKR 50,000. Paid PKR 60,000. Balance: −PKR 10,000 (we owe them).  
Customer C: Total purchases PKR 200,000. Paid PKR 200,000. Balance: PKR 0.  
**Total Outstanding Receivables:** PKR 20,000 (Customer A only)  
**Amount Owed to Customers:** PKR 10,000 (Customer B — credit note or refund pending)

---

### S-59: Editing Purchase — Quantity Reduced (Safe)
**Input:**  
Original purchase: 10 iPhones at PKR 80,000. 3 have been sold.  
Edit purchase: Change qty to 8.  
**Validation:** 8 >= 3 (quantity sold). Edit allowed.  
**Stock change:** From 10−3=7 remaining to 8−3=5 remaining. Net: −2 units.  
**WAC:** Recalculated.

---

### S-60: Editing Purchase — Quantity Reduced (Blocked)
**Input:**  
Original purchase: 10 iPhones. 8 have been sold.  
Attempt to edit qty to 5.  
**Validation:** 5 < 8. BLOCKED. Error: "Cannot reduce purchase quantity below already-sold quantity (8)."

---

## REPORTING SCENARIOS

### S-61: Gross Profit Margin Report
**Input:**  
Net Sales: PKR 500,000  
Net COGS: PKR 350,000  
**Gross Profit:** 150,000  
**Gross Margin %:** (150,000 / 500,000) × 100 = **30%**

---

### S-62: Inventory Value Report
**Input:**  
Product A: 10 units, WAC PKR 80,000 → Value PKR 800,000  
Product B: 50 units, WAC PKR 500 → Value PKR 25,000  
Product C: 0 units → Value PKR 0  
**Total Inventory Value:** PKR 825,000

---

### S-63: Outstanding Balance Report
**Input:**  
5 customers with balances: +10,000 / +5,000 / 0 / −2,000 / +8,000  
**Total Receivables:** 10,000 + 5,000 + 8,000 = PKR 23,000  
**Total Credit Notes Owed:** PKR 2,000

---

---

# APPENDIX A — FORMULA QUICK REFERENCE

| Metric | Formula |
|--------|---------|
| WAC | (existing_value + incoming_value) / (existing_qty + incoming_qty) |
| Line Total | (unit_price × qty) − line_discount |
| Invoice Grand Total | subtotal − invoice_discount |
| Balance Due | grand_total − amount_paid |
| Customer Balance | total_purchases − total_returns_received − total_payments |
| Supplier Balance | total_purchases_from_supplier − total_returns_made − total_payments_made |
| COGS (sale item) | unit_cost_at_sale × qty_sold |
| Gross Profit | Net Sales − Net COGS |
| Net Profit | Gross Profit − Expenses − Damages − Adj.Losses + Adj.Gains |
| Inventory Value | sum(qty_on_hand × avg_cost) per product |
| Cash Balance | Opening + Inflows − Outflows |
| Damage Loss | avg_cost × qty_damaged |

---

# APPENDIX B — BUSINESS RULES SUMMARY

| # | Rule |
|---|------|
| BR-01 | Negative stock is forbidden. Block all transactions that would result in negative stock. |
| BR-02 | COGS must be captured at time of sale using the current WAC. The snapshot is immutable. |
| BR-03 | Revenue is recognized at time of sale, not at time of cash receipt. |
| BR-04 | Dealer Issue does not recognize revenue or profit. |
| BR-05 | Discounts reduce revenue and gross profit. They do not affect COGS. |
| BR-06 | Expenses reduce net profit only, not gross profit. |
| BR-07 | Damage losses reduce net profit only, not gross profit. |
| BR-08 | Sales Return reverses revenue and COGS proportionally. |
| BR-09 | Purchase Return reverses inventory cost basis. No profit impact. |
| BR-10 | WAC is recalculated on every stock increase. WAC does not change on stock decrease. |
| BR-11 | Invoice discounts on sales returns must be prorated proportionally to returned items. |
| BR-12 | Deleting a transaction reverses all its financial and stock effects. |
| BR-13 | Editing a transaction = delete old effects + apply new effects. |
| BR-14 | Cash Received from customer and Cash Paid to supplier are balance settlements — not revenue or cost events. |
| BR-15 | Stock adjustments are treated as inventory gains (positive) or losses (negative) affecting net profit. |

---

*End of Document*
