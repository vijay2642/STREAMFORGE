import React from 'react';
import { render, screen } from '@testing-library/react';
import App from './App';

test('renders stream player', () => {
  render(<App />);
  const playerElement = screen.getByText(/React Live Stream Player/i);
  expect(playerElement).toBeTruthy();
});
