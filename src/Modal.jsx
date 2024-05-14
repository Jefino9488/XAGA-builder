import React from 'react';
import './Modal.css'; // Make sure to create this CSS file for styling

const Modal = ({ show, onClose, onConfirm, message }) => {
  if (!show) {
    return null;
  }

  return (
    <div className="modal-backdrop">
      <div className="modal-content">
        <h2>{message}</h2>
        <button onClick={onConfirm}>Proceed</button>
        <button onClick={onClose}>Cancel</button>
      </div>
    </div>
  );
};

export default Modal;
