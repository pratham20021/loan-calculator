package com.loan;

public class LoanResponse {
    private double emi;
    private double totalAmount;
    private double totalInterest;

    public LoanResponse(double emi, double totalAmount, double totalInterest) {
        this.emi = Math.round(emi * 100.0) / 100.0;
        this.totalAmount = Math.round(totalAmount * 100.0) / 100.0;
        this.totalInterest = Math.round(totalInterest * 100.0) / 100.0;
    }

    public double getEmi() { return emi; }
    public double getTotalAmount() { return totalAmount; }
    public double getTotalInterest() { return totalInterest; }
}
