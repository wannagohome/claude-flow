# Stage: system-design

Design **interface-level contracts** based on the spec.
No implementation details (function bodies, detailed logic). Only reviewable contracts.

## Input

- Spec documents: All files in `{BASE_DIR}/spec/`
- Integration test plan (if exists): `{BASE_DIR}/test-plan/integration/test-plan-integration.md`

## Output

```
{BASE_DIR}/design/
├── interfaces.md    # All interface definitions (single file)
└── _shared.md       # Shared constants, error codes (if needed)
```

## Design Scope -- Interfaces Only

### What to Include

- Domain Model **type signatures**
- Repository Interface **method signatures**
- UseCase / Service Interface **method signatures**
- DTO types (Request/Response **shapes only**)
- Store / State **type definitions**
- ViewModel / Controller **return types**
- API endpoint list (path, method, request/response type names)
- View **component tree** (which components contain which sub-components)

### What NOT to Include

- Function implementations or logic
- Mapper/transformer logic
- Props details or styles
- DI/IoC binding configuration
- Route configuration
- Database schemas or migration scripts

## Design Approach

1. **Read the project's conventions file** (e.g., CLAUDE.md, CONVENTIONS.md, or equivalent) to understand architecture patterns, naming conventions, and structural rules.
2. **Follow the project's architecture** -- whether it uses Clean Architecture, MVC, MVVM, hexagonal, or any other pattern. Design interfaces that fit the existing structure.
3. **Match existing code style** -- if the project uses `type` over `interface`, functional over class-based, etc., follow that convention.

## Example -- This Level of Detail is Appropriate

```typescript
// Domain Model
type Order = {
  id: string;
  items: OrderItem[];
  status: OrderStatus;
  totalAmount: number;
  createdAt: Date;
};

// Repository Interface
type OrderRepository = {
  createOrder(items: OrderItem[]): Promise<Order>;
  getOrder(id: string): Promise<Order>;
  listOrders(filter: OrderFilter): Promise<Order[]>;
};

// UseCase / Service Interface
type CreateOrderUseCase = {
  execute(items: OrderItem[]): Promise<Order>;
};

// API
// POST /api/v1/orders -- CreateOrderRequest -> CreateOrderResponse
// GET  /api/v1/orders/:id -- -> GetOrderResponse
// GET  /api/v1/orders?status={status} -- -> ListOrdersResponse

// View Component Tree
// OrderScreen
// ├── OrderHeader
// ├── OrderItemList
// │   └── OrderItemCard
// ├── OrderSummary
// └── PlaceOrderButton
```

## Procedure

1. Read all spec documents
2. If test-plan-integration.md exists, reference it (understand which parameters are tested)
3. Write `{BASE_DIR}/design/interfaces.md`
4. If shared constants/error codes are needed, write `{BASE_DIR}/design/_shared.md`
5. Write result to `{RESULT_FILE}`

## Result

```json
{
  "status": "complete",
  "findings": 0,
  "fixed": 0,
  "artifacts": [
    "{BASE_DIR}/design/interfaces.md"
  ],
  "summary": "Domain Model N types, Repository Interface M types, UseCase K types, API endpoints L defined"
}
```
