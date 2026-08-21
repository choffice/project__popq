import type { SellerConnection } from "../../types";
import { AdminSupportManagement } from "./AdminSupportManagement";

type Props = {
  connection: SellerConnection | null;
  onError: (message: string | null) => void;
};

export function AdminSupportHub({ connection, onError }: Props) {
  return <AdminSupportManagement connection={connection} onError={onError} />;
}
