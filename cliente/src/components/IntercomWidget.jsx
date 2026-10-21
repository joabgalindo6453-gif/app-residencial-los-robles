import React, { useState } from 'react';

export default function IntercomWidget() {
  const [isMicOn, setIsMicOn] = useState(false);

  return (
    <div className="intercom-panel">
      <h3>Intercomunicador (WebRTC)</h3>
      {/* Indicador LED solicitado por la PO */}
      <div style={{ color: isMicOn ? 'green' : 'red', fontWeight: 'bold' }}>
        {isMicOn ? '🟢 Micrófono Encendido' : '🔴 Micrófono Apagado'}
      </div>
      <button onClick={() => setIsMicOn(!isMicOn)}>
        {isMicOn ? 'Apagar Micrófono' : 'Encender Micrófono'}
      </button>
    </div>
  );
}
