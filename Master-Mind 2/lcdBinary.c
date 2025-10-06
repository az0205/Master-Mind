/* ***************************************************************************** */
/* You can use this file to define the low-level hardware control fcts for       */
/* LED, button and LCD devices.                                                  */ 
/* Note that these need to be implemented in Assembler.                          */
/* You can use inline Assembler code, or use a stand-alone Assembler file.       */
/* Alternatively, you can implement all fcts directly in master-mind.c,          */  
/* using inline Assembler code there.                                            */
/* The Makefile assumes you define the functions here.                           */
/* ***************************************************************************** */


#ifndef	TRUE
#  define	TRUE	(1==1)
#  define	FALSE	(1==2)
#endif

#define	PAGE_SIZE		(4*1024)
#define	BLOCK_SIZE		(4*1024)

#define	INPUT			 0
#define	OUTPUT			 1

#define	LOW			 0
#define	HIGH			 1


// APP constants   ---------------------------------

// Wiring (see call to lcdInit in main, using BCM numbering)
// NB: this needs to match the wiring as defined in master-mind.c

#define STRB_PIN 24
#define RS_PIN   25
#define DATA0_PIN 23
#define DATA1_PIN 10
#define DATA2_PIN 27
#define DATA3_PIN 22

// -----------------------------------------------------------------------------
// includes 
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/types.h>
#include <time.h>

// -----------------------------------------------------------------------------
// prototypes

int failure (int fatal, const char *message, ...);

// -----------------------------------------------------------------------------
// Functions to implement here (or directly in master-mind.c)

/* this version needs gpio as argument, because it is in a separate file */
void digitalWrite (uint32_t *gpio, int pin, int value) {
  asm volatile (
    "\tmov r0, %[gpio]\n\t"       // r0 = base address of GPIO registers
    "\tmov r1, %[pin]\n\t"        // r1 = LED pin number
    "\tmov r2, %[value]\n\t"      // r2 = LED value (nonzero: ON, zero: OFF)
    "\tcmp r2, #0\n\t"            // Compare value with 0
    "\tbeq off\n\t"              // If zero, branch to off label
    "\tadd r0, r0, #28\n\t"       // For LED ON, add offset for GPSET0 (28 bytes)
    "\tb compute_mask\n\t"       // Jump to compute mask
    "off:\n\t"
    "\tadd r0, r0, #40\n\t"       // For LED OFF, add offset for GPCLR0 (40 bytes)
    "compute_mask:\n\t"
    "\tand r1, r1, #31\n\t"       // r1 = LED pin & 31 (get bit position)
    "\tmov r3, #1\n\t"            // r3 = 1
    "\tlsl r3, r3, r1\n\t"        // r3 = 1 << (LED pin & 31)
    "\tstr r3, [r0]\n\t"          // Write the mask to the computed register
    : 
    : [gpio] "r" (gpio), [pin] "r" (pin), [value] "r" (value)
    : "r0", "r1", "r2", "r3", "cc"
  );

  
}

// adapted from setPinMode
void pinMode(uint32_t *gpio, int pin, int mode /*, int fSel, int shift */) {
  asm volatile (
    "\tmov r0, %[gpio]\n\t"         // r0 = base address of GPIO registers
    "\tmov r1, %[pin]\n\t"          // r1 = pin number
    "\tmov r2, %[mode]\n\t"        // r2 = desired mode (e.g., 0 for input, 1 for output)
    "\tmov r7, r1\n\t"              // r7 = copy of pin (for division)
    "\tmov r3, #0\n\t"              // r3 = quotient = 0
    "\tmov r8, #10\n\t"             // r8 = constant 10
    "div_loop:\n\t"
    "\tcmp r7, r8\n\t"             // compare r7 with 10
    "\tblt div_done\n\t"           // if r7 < 10, exit loop
    "\tsub r7, r7, r8\n\t"          // r7 = r7 - 10
    "\tadd r3, r3, #1\n\t"          // quotient++
    "\tb div_loop\n\t"
    "div_done:\n\t"
    "\tmov r9, #4\n\t"             // r9 = 4
    "\tmul r5, r3, r9\n\t"          // r5 = quotient * 4 (byte offset for register)
    "\tadd r0, r0, r5\n\t"          // r0 = gpio base + register offset (target register address)
    "\tmov r9, #3\n\t"             // r9 = 3
    "\tmul r4, r7, r9\n\t"          // r4 = remainder * 3 (bit shift for the pin)
    "\tldr r5, [r0]\n\t"            // r5 = current mode at target register
    "\tmov r7, #7\n\t"              // r7 = 7 (binary 111 mask for 3 bits)
    "\tlsl r7, r7, r4\n\t"          // r7 = 7 << shift (mask for pin's 3 bits)
    "\tmvn r7, r7\n\t"              // r7 = ~(7 << shift) (inverted mask to clear bits)
    "\tand r5, r5, r7\n\t"          // r5 = current register mode with pin's bits cleared
    "\tmov r7, r2\n\t"              // r7 = desired mode
    "\tlsl r7, r7, r4\n\t"          // r7 = mode << shift (position mode bits)
    "\torr r5, r5, r7\n\t"          // r5 = new register mode with mode set for the pin
    "\tstr r5, [r0]\n\t"            // store the modified mode back to the target register
    : 
    : [gpio] "r" (gpio), [pin] "r" (pin), [mode] "r" (mode)
    : "r0", "r1", "r2", "r3", "r4", "r5", "r7", "r8", "r9", "cc"

);
}

void writeLED(uint32_t *gpio, int led, int value) {
  digitalWrite(gpio, led, value);
}

int readButton(uint32_t *gpio, int button) {
  int result;
  
  asm volatile (
      "\tldr r1, [%[gpio], #52]\n\t"  // r1 = *(gpio + 52) = value of GPLEV0 (32-bit register for GPIO 031)
      "\tmov r2, %[button]\n\t"       // r2 = button pin number
      "\tand r2, r2, #31\n\t"         // r2 = button pin number masked to 031 (bit position)
      "\tmov r3, #1\n\t"              // r3 = constant 1
      "\tlsl r3, r3, r2\n\t"          // r3 = 1 << (button pin & 31), creates the bit mask
      "\tand r1, r1, r3\n\t"          // r1 = GPLEV0 value AND mask, isolating the button's bit
      "\tmov %[result], r1\n\t"       // output: result = isolated bit (nonzero if HIGH, zero if LOW)
      : [result] "=r" (result)
      : [gpio] "r" (gpio), [button] "r" (button)
      : "r1", "r2", "r3", "memory", "cc"
  );

  return result;
  
}

/* Repeatedly loops until the button is pressed where it will exit loop and continue program */
void waitForButton(uint32_t *gpio, int button) {
  
  while (!readButton(gpio, button)){
  }

}
