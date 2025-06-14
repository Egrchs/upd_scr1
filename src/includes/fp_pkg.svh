// Copyright 2021 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Florian Zaruba, ETH Zurich
//
// Description: Package containing common definitions for FPNew.

package fp_pkg;

    // FPU operations
    typedef enum logic [4:0] {
        FP_ADD,
        FP_SUB,
        FP_MUL,
        FP_DIV,
        FP_SQRT,
        FP_SGNJ,
        FP_MINMAX,
        FP_CMP,
        FP_CLASSIFY,
        FP_F2I,
        FP_I2F,
        FP_F2F,
        FP_MV_X_F,
        FP_MV_F_X,
        FP_MADD,
        FP_MSUB
    } fpnew_op_e;

    // Operation modifiers for SGNJ, MINMAX, F2I
    typedef enum logic [1:0] {
        OP_MOD_SGNJ,
        OP_MOD_SGNJN,
        OP_MOD_SGNJX
    } fpnew_op_mod_e;
    typedef enum logic [2:0] {
        FMT_H,
        FMT_S,
        FMT_D,
        FMT_Q
    } fpnew_fmt_e;
    // Supported formats

    // Supported integer formats
    typedef enum logic [1:0] {
        INT_W,
        INT_L
    } fpnew_int_fmt_e;

    // Supported rounding modes
    typedef enum logic [2:0] {
        RNE, // Round to nearest, ties to even
        RTZ, // Round towards zero
        RDN, // Round down
        RUP, // Round up
        RMM, // Round to nearest, ties to max magnitude
        DYN  // Dynamic rounding mode
    } fpnew_rnd_mode_e;

    // Exception flags
    typedef struct packed {
        logic NV; // Invalid operation
        logic DZ; // Division by zero
        logic OF; // Overflow
        logic UF; // Underflow
        logic NX; // Inexact
    } fpnew_exc_flags_t;

    // Format definitions (W=width, E=exponent, M=mantissa)
    parameter int unsigned FpWidth = 32;

    parameter int unsigned FpExpWidth = 8;

    parameter int unsigned FpManWidth = 23;

endpackage
