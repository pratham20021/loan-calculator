package com.loan;

import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/loan")
@CrossOrigin(origins = "*")
public class LoanController {

    @PostMapping("/calculate")
    public LoanResponse calculate(@RequestBody LoanRequest request) {
        double P = request.getPrincipal();
        double r = request.getAnnualInterestRate() / 12 / 100; // monthly rate
        int n = request.getTenureMonths();

        double emi;
        if (r == 0) {
            emi = P / n;
        } else {
            emi = (P * r * Math.pow(1 + r, n)) / (Math.pow(1 + r, n) - 1);
        }

        double totalAmount = emi * n;
        double totalInterest = totalAmount - P;

        return new LoanResponse(emi, totalAmount, totalInterest);
    }
}
