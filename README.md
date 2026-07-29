# SPI Bus Protocol with Built-In Self-Test (BIST)

This project implements the **Serial Peripheral Interface (SPI) Bus Protocol** along with an integrated **Built-In Self-Test (BIST)** module in Verilog. The design demonstrates reliable SPI communication between master and slave devices while incorporating self-test functionality to verify correct operation without requiring extensive external test equipment.

## Features

* SPI Master and Slave implementation
* Supports standard SPI communication (MOSI, MISO, SCLK, CS)
* Built-In Self-Test (BIST) for automatic functional verification
* Modular and synthesizable Verilog design
* Comprehensive testbench for simulation and validation
* Suitable for FPGA implementation and digital design learning

## Project Structure

* **SPI Master** – Generates clock, chip select, and controls data transmission.
* **SPI Slave** – Receives and transmits data according to SPI protocol.
* **BIST Module** – Automatically generates test patterns, applies them to the SPI interface, and checks the responses for correctness.
* **Testbench** – Verifies normal SPI operation as well as BIST functionality.

## Applications

* FPGA and ASIC design projects
* Digital communication systems
* Embedded systems
* Hardware verification and self-testing
* Educational projects for learning SPI protocol and Design-for-Test (DFT) concepts

## Tools Used

* Verilog HDL
* ModelSim / QuestaSim / Vivado Simulator (or any Verilog simulator)

## Future Enhancements

* Support for MODE 0 only
* Configurable clock divider
* Error logging and diagnostic reporting
* Multiple slave support
* SystemVerilog/UVM-based verification environment

This repository is intended for students, FPGA developers, and VLSI engineers looking to understand SPI communication, hardware design, and Built-In Self-Test (BIST) implementation in a practical and modular way.
