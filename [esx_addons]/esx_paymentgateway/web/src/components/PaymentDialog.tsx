import { ArrowRight, BadgeCheck, X } from "lucide-react";
import { Button, Card } from "esx-ui-kit-react";
import {
  defaultMethods,
  formatMoney,
  hasSufficientFunds,
} from "../lib/payment";
import type { PaymentMethod, PaymentRequest, PaymentStatus } from "../types/payment";
import { PaymentMethodOption } from "./PaymentMethodOption";

type Props = {
  paymentRequest: PaymentRequest;
  method: PaymentMethod;
  status: PaymentStatus;
  message: string;
  logoUrl?: string;
  onMethodChange: (method: PaymentMethod) => void;
  confirm: () => void;
  cancel: () => void;
  retry: () => void;
};
export function PaymentDialog({
  paymentRequest,
  method,
  status,
  message,
  logoUrl,
  onMethodChange,
  confirm,
  cancel,
  retry,
}: Props) {
  const result = status === "success" || status === "failure";
  const methods = paymentRequest.methods ?? defaultMethods;
  const disabled =
    status === "processing" || !hasSufficientFunds(paymentRequest, method);
  return (
    <Card
      variant="bordered"
      className="modal"
      role="dialog"
      aria-modal="true"
      aria-labelledby="dialog-title"
    >
      <header className="topbar">
        <div className="brand" aria-label="ESX">
          <img src={logoUrl || "/esx.svg"} className="h-6" alt="ESX" />
        </div>
        <button className="icon-button" onClick={cancel} aria-label="Close">
          <X size={19} />
        </button>
      </header>
      {result ? (
        <section className="result-view">
          <div className={`result-icon ${status}`}>
            {status === "success" ? <BadgeCheck size={35} /> : <X size={32} />}
          </div>
          <p className="eyebrow">
            {status === "success"
              ? "PAYMENT CONFIRMED"
              : "PAYMENT NOT COMPLETED"}
          </p>
          <h1 id="dialog-title">
            {status === "success" ? "You’re all set." : "Something went wrong."}
          </h1>
          <p className="result-copy">{message}</p>
          <div className="result-amount">
            {paymentRequest.currency}
            {formatMoney(paymentRequest.amount)}
            <span>{paymentRequest.title}</span>
          </div>
          {status === "success" ? (
            <Button
              variant="primary"
              size="lg"
              className="action-button"
              onClick={cancel}
            >
              DONE <ArrowRight size={17} />
            </Button>
          ) : (
            <Button
              variant="primary"
              size="lg"
              className="action-button"
              onClick={retry}
            >
              TRY AGAIN <ArrowRight size={17} />
            </Button>
          )}
        </section>
      ) : (
        <>
          <section className="content">
            <div className="intro">
              <p className="eyebrow">
                {paymentRequest.title}
                {paymentRequest.description ? (
                  <span> · {paymentRequest.description}</span>
                ) : null}
              </p>
              <h1 id="dialog-title">COMPLETE PURCHASE</h1>
              <p className="intro-copy">Choose your preferred payment method</p>
            </div>
            <div className="amount">
              <span>AMOUNT</span>
              <strong>
                {paymentRequest.currency}
                {formatMoney(paymentRequest.amount)}
              </strong>
            </div>
            <div className="methods">
              {methods.includes("cash") && (
                <PaymentMethodOption
                  method="cash"
                  paymentRequest={paymentRequest}
                  selected={method === "cash"}
                  onSelect={() => onMethodChange("cash")}
                />
              )}
              {methods.includes("card") && (
                <PaymentMethodOption
                  method="card"
                  paymentRequest={paymentRequest}
                  selected={method === "card"}
                  onSelect={() => onMethodChange("card")}
                />
              )}
            </div>
          </section>
          <footer className="footer">
            <Button
              variant="primary"
              size="lg"
              className="confirm-button"
              disabled={disabled}
              onClick={confirm}
            >
              {status === "processing" ? "PROCESSING…" : "CONFIRM PAYMENT"}
            </Button>
            <Button
              variant="outline"
              size="lg"
              className="cancel-button"
              onClick={cancel}
            >
              CANCEL
            </Button>
          </footer>
        </>
      )}
    </Card>
  );
}
