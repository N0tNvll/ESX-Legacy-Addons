import { createRoot } from "react-dom/client";
import "esx-ui-kit-react/style.css";
import "./style.css";
import "./nui.css";
import { PaymentDialog } from "./components/PaymentDialog";
import { usePaymentGateway } from "./hooks/usePaymentGateway";

function App() {
  const gateway = usePaymentGateway();

  return (
    <main
      className={`stage ${gateway.open ? "is-open" : ""}`}
      aria-hidden={!gateway.open}
    >
      {gateway.open && (
        <PaymentDialog {...gateway} onMethodChange={gateway.setMethod} />
      )}
    </main>
  );
}

createRoot(document.getElementById("app")!).render(<App />);
