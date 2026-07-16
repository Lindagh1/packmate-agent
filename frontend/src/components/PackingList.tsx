import type { PackingItem } from "../models/packmate";

interface PackingListProps {
  items: PackingItem[];
}

export function PackingList({ items }: PackingListProps) {
  if (items.length === 0) {
    return <p className="lab-empty">No packing items were returned.</p>;
  }

  return (
    <div className="lab-table-wrap">
      <table className="lab-table" aria-label="Packing list">
        <thead>
          <tr>
            <th scope="col">Name</th>
            <th scope="col">Category</th>
            <th scope="col">Qty</th>
            <th scope="col">Reason</th>
            <th scope="col">Priority</th>
          </tr>
        </thead>
        <tbody>
          {items.map((item) => (
            <tr key={`${item.name}-${item.category}-${item.quantity}`}>
              <td data-label="Name">{item.name}</td>
              <td data-label="Category">{item.category}</td>
              <td data-label="Quantity">{item.quantity}</td>
              <td data-label="Reason">{item.reason}</td>
              <td data-label="Priority">
                <span
                  className={`lab-badge ${
                    item.essential ? "lab-badge--essential" : "lab-badge--optional"
                  }`}
                >
                  {item.essential ? "Essential" : "Optional"}
                </span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
