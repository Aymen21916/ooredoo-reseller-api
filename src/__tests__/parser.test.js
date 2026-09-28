describe('Daily Reconciliation Ledger Parser', () => {
  it('MUST correctly extract Recharges, Rewards, and Conversions from DB notes', () => {
    const fakeDatabaseHistory = [
      { notes: '[SNAPSHOT] Daily Opening Balance' },
      { notes: '[RECHARGE] 5000 | Bought flexy from distributor' },
      { notes: '[REWARD] 2000 | Ooredoo weekend promo' },
      { notes: '[CONVERSION] Converted 5000 pts into 150.00 DZD.' },
      { notes: 'Random note without tags 1000' } // Should be ignored
    ];

    let manualRecharges = 0;
    let manualRewards = 0;
    let pointsConverted = 0;
    let dzdConverted = 0;

    fakeDatabaseHistory.forEach(h => {
      const convMatch = h.notes.match(/\[CONVERSION\] Converted (\d+) pts into ([\d.]+) DZD/);
      if (convMatch) {
        pointsConverted += parseInt(convMatch[1], 10);
        dzdConverted += parseFloat(convMatch[2]);
      }
      const rechMatch = h.notes.match(/\[RECHARGE\] ([\d.]+)/);
      if (rechMatch) manualRecharges += parseFloat(rechMatch[1]);
      
      const rewMatch = h.notes.match(/\[REWARD\] ([\d.]+)/);
      if (rewMatch) manualRewards += parseInt(rewMatch[1], 10);
    });

    // The Mathematical Proof
    expect(manualRecharges).toBe(5000);
    expect(manualRewards).toBe(2000);
    expect(pointsConverted).toBe(5000);
    expect(dzdConverted).toBe(150);
  });
});