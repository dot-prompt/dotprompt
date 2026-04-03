// Phoenix and LiveView entry point
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";

// CSRF token - get from meta tag
const metaToken = document.querySelector("meta[name='csrf-token']");
const csrfToken = metaToken ? metaToken.content : "";

// Debug status element
function setStatus(text, type) {
  const status = document.getElementById('lv-status');
  if (status) {
    status.textContent = text;
    status.className = `liveview-status liveview-${type}`;
  }
}

const hooks = {
  SectionEdit: {
    mounted() {
      this.el.addEventListener("dblclick", () => {
        this.pushEvent("edit_line", { index: this.el.dataset.index });
      });
    },
    updated() {
      const input = this.el.querySelector("input[type='text']");
      if (input) {
        input.focus();
        // Move cursor to end
        const val = input.value;
        input.value = "";
        input.value = val;
        
        // Handle Enter and Escape keys
        input.addEventListener("keydown", (e) => {
          if (e.key === "Enter") {
            // Save and blur to trigger phx-blur="save_line"
            input.blur();
          } else if (e.key === "Escape") {
            // Cancel editing by blurring
            input.blur();
          }
        });
      }
    }
  },
  Resizable: {
    mounted() {
      this.el.addEventListener("mousedown", e => {
        e.preventDefault();
        const targetId = this.el.dataset.targetId;
        const target = document.getElementById(targetId);
        if (!target) return;

        const startX = e.clientX;
        const startWidth = target.offsetWidth;

        const onMouseMove = e => {
          const delta = e.clientX - startX;
          const side = this.el.dataset.side || "left";
          const newWidth = side === "right" ? startWidth - delta : startWidth + delta;
          target.style.width = `${newWidth}px`;
          target.style.flex = "none";
        };

        const onMouseUp = () => {
          document.removeEventListener("mousemove", onMouseMove);
          document.removeEventListener("mouseup", onMouseUp);
          this.pushEvent("resize", { id: targetId, width: target.offsetWidth });
        };

        document.addEventListener("mousemove", onMouseMove);
        document.addEventListener("mouseup", onMouseUp);
      });
    }
  }
};

// Connect LiveView
function connectLiveView() {
  setStatus('LV: Connecting...', 'disconnected');
  
  try {
    const liveSocket = new LiveSocket("/live", Socket, {
      params: {
        _csrf_token: csrfToken
      },
      hooks: hooks
    });
    
    // Connect
    liveSocket.connect();
    window.liveSocket = liveSocket;
    
    setStatus('LV: Connected', 'connected');
    console.log("LiveView socket created and connecting...");
    
  } catch (e) {
    console.error("Failed to create LiveView:", e);
    setStatus('LV: Failed', 'error');
  }
}

// Connect when DOM is ready
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", connectLiveView);
} else {
  connectLiveView();
}
