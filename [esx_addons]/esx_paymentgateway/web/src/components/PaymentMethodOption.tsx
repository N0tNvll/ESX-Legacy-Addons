import { Banknote, CreditCard, Check, CircleAlert } from "lucide-react";
import { Card } from "esx-ui-kit-react";
import { formatMoney, getBalance, hasSufficientFunds } from "../lib/payment";
import type { PaymentMethod, PaymentRequest } from "../types/payment";

type Props = {
  method: PaymentMethod;
  paymentRequest: PaymentRequest;
  selected: boolean;
  onSelect: () => void;
};
export function PaymentMethodOption({
  method,
  paymentRequest,
  selected,
  onSelect,
}: Props) {
  const label = method === "cash" ? "Cash" : "Card";
  const balance = getBalance(paymentRequest, method);
  const insufficient = !hasSufficientFunds(paymentRequest, method);
  const Icon = method === "cash" ? Banknote : CreditCard;
  return (
    <Card
      variant="bordered"
      className={`payment-option ${selected ? "selected" : ""} ${insufficient ? "unavailable" : ""}`}
    >
      <button
        type="button"
        className="option-button"
        onClick={onSelect}
        disabled={insufficient}
        aria-pressed={selected}
        aria-label={`${label}${insufficient ? ", insufficient funds" : ""}`}
      >
        <span className="option-radio">
          {selected && !insufficient ? <Check size={13} /> : null}
        </span>
        <Icon className="option-icon" size={34} strokeWidth={2.1} />
        <strong>{label}</strong>
        <span className="option-subtitle">
          {method === "cash" ? "Pay with cash" : "Pay from bank account"}
        </span>
        {balance !== undefined && (
          <span className="option-balance">
            {insufficient ? (
              <>
                <CircleAlert size={12} /> Not enough funds
              </>
            ) : (
              <>
                Available {paymentRequest.currency}
                {formatMoney(balance)}
              </>
            )}
          </span>
        )}
      </button>
    </Card>
  );
}
