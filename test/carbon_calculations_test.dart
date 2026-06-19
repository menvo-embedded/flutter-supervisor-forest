import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Carbon Projection and ESG Calculations Tests', () {
    test('Should calculate correct carbon projection based on area and growth rate', () {
      const double areaHa = 1250.0;
      const double growthRate = 8.0; // tCO2e/ha/year
      const int targetYear = 15;

      // IPCC style formula: Area * Growth Rate * Years
      const double co2Accumulated = areaHa * growthRate * targetYear;

      expect(co2Accumulated, 150000.0); // 1250 * 8 * 15 = 150,000 tCO2e
    });

    test('Should compute correct ESG financial tracker components', () {
      const double carbonCreditsTotal = 25430.0;
      const double creditPriceUsd = 12.0;

      // 1. Gross Revenue
      const double grossRevenue = carbonCreditsTotal * creditPriceUsd;
      expect(grossRevenue, 305160.0); // 25,430 * 12 = 305,160

      // 2. OpEx Cost (22% patrolling cost + fixed management $15,000)
      const double opCost = grossRevenue * 0.22 + 15000.0;
      expect(opCost, 82135.2); // 305,160 * 0.22 + 15,000 = 67,135.2 + 15,000 = 82,135.2

      // 3. ESG Reinvestment (15%)
      const double esgReinvestment = grossRevenue * 0.15;
      expect(esgReinvestment, 45774.0); // 305,160 * 0.15 = 45,774

      // 4. Net Profit (Gross - OpEx - ESG)
      const double netProfit = grossRevenue - opCost - esgReinvestment;
      expect(netProfit, 177250.8); // 305,160 - 82,135.2 - 45,774 = 177,250.8

      // 5. Margin percentage
      const double profitMargin = netProfit / grossRevenue;
      expect(profitMargin, closeTo(0.58, 0.01)); // ~58%
    });
  });
}
