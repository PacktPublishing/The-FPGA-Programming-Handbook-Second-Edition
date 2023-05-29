/******************************************************************************
*
* Copyright (C) 2009 - 2014 Xilinx, Inc.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* Use of the Software is limited solely to applications:
* (a) running on a Xilinx device, or
* (b) that interact with a Xilinx device through a bus or interconnect.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
* XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
* OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*
* Except as contained in this notice, the name of the Xilinx shall not be used
* in advertising or otherwise to promote the sale, use or other dealings in
* this Software without prior written authorization from Xilinx.
*
******************************************************************************/

/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include <stdio.h>
#include "platform.h"
#include "xparameters.h"
#include "xil_printf.h"
#include "xgpio.h"
#include "xil_types.h"

// Get device IDs from xparameters.h
#define BTN_ID XPAR_AXI_GPIO_PUSHBUTTON_DEVICE_ID
#define LED_ID XPAR_AXI_GPIO_LED16_DEVICE_ID
#define SW_ID XPAR_AXI_GPIO_SWITCH16_DEVICE_ID
#define BTN_CHANNEL 1
#define LED_CHANNEL 1
#define SW_CHANNEL 1
#define BTN_MASK 0b11111
#define LED_MASK 0b1111111111111111
#define SW_MASK 0b1111111111111111
#define btnc 1 << 0
#define btnu 1 << 1
#define btnl 1 << 2
#define btnr 1 << 3
#define btnd 1 << 4

int main()
{
	XGpio_Config *cfg_ptr;
	XGpio led_device, btn_device, sw_device;
	u32 btn_data, sw_data, last_data;
	u32 accumulator = 0;
    init_platform();

    print("Hello World\n\r");

	// Initialize LED Device
	cfg_ptr = XGpio_LookupConfig(LED_ID);
	XGpio_CfgInitialize(&led_device, cfg_ptr, cfg_ptr->BaseAddress);

	// Initialize Button Device
	cfg_ptr = XGpio_LookupConfig(BTN_ID);
	XGpio_CfgInitialize(&btn_device, cfg_ptr, cfg_ptr->BaseAddress);

	// Initialize Switch Device
	cfg_ptr = XGpio_LookupConfig(SW_ID);
	XGpio_CfgInitialize(&sw_device, cfg_ptr, cfg_ptr->BaseAddress);

	// Set Button Tristate
	XGpio_SetDataDirection(&btn_device, BTN_CHANNEL, BTN_MASK);

	// Set Led Tristate
	XGpio_SetDataDirection(&led_device, LED_CHANNEL, 0);

	// Set Switch Tristate
	XGpio_SetDataDirection(&sw_device, LED_CHANNEL, 0);

	// Implement our simple calculator using the microblaze
	while (1) {
		btn_data = XGpio_DiscreteRead(&btn_device, BTN_CHANNEL);
		btn_data &= BTN_MASK;
		sw_data  = XGpio_DiscreteRead(&sw_device, SW_CHANNEL);

		switch (btn_data & ~last_data) {
			case btnu :
				accumulator *= sw_data;
				xil_printf("SW: %d\n", sw_data);
				xil_printf("Multiply Accumulator = %d\n", accumulator);
				break;
			case btnl :
				accumulator += sw_data;
				xil_printf("SW: %d\n", sw_data);
				xil_printf("Add Accumulator = %d\n", accumulator);
				break;
			case btnr :
				accumulator -= sw_data;
				xil_printf("SW: %d\n", sw_data);
				xil_printf("Subtract Accumulator = %d\n", accumulator);
				break;
			case btnd :
				accumulator /= sw_data;
				xil_printf("SW: %d\n", sw_data);
				xil_printf("Divide Accumulator = %d\n", accumulator);
				break;
		}
		last_data = btn_data;
		XGpio_DiscreteWrite(&led_device, LED_CHANNEL, accumulator);
	}

    cleanup_platform();
    return 0;
}
