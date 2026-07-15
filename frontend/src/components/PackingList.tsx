import {
  Card,
  CardBody,
  CardTitle,
  Label,
} from "@patternfly/react-core";
import type { PackingItem } from "../models/packmate";

interface PackingListProps {
  items: PackingItem[];
}

export function PackingList({ items }: PackingListProps) {
  if (items.length === 0) {
    return (
      <Card>
        <CardTitle>Packing list</CardTitle>
        <CardBody>No packing items were returned.</CardBody>
      </Card>
    );
  }

  return (
    <Card>
      <CardTitle>Packing list</CardTitle>
      <CardBody>
        <table
          className="pf-v6-c-table pf-m-compact pf-m-striped pf-m-grid-md"
          aria-label="Packing list"
        >
          <thead>
            <tr>
              <th scope="col">Name</th>
              <th scope="col">Category</th>
              <th scope="col">Quantity</th>
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
                  <Label color={item.essential ? "green" : "blue"} isCompact>
                    {item.essential ? "Essential" : "Optional"}
                  </Label>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </CardBody>
    </Card>
  );
}
