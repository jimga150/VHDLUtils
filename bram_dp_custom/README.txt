This module instantiates a number of block RAM primitives (you can customize what the dimensions of that primitive are) into a larger block RAM module, utilizing as few primitives as possible (within the constraints of the width and depth of the primitives).

The reason i wrote this is to pipeline the output data multiplexer in a parameterizable way. Vivado's synthesizer, while supporting RAM primitive saving, does not support for inserting registers into the resulting data multiplexer, when using BRAM implication.
This module will insert any number of stages into the multiplexer logic, helping you close timing on large block RAM modules that need to aviod wasting primitives by configuring the primitives to use 1 bit wide data.

Configure the primitive you want to use by changing the constants in bram_dp_custom_pkg, and/or modifying bram_dp_primitive, and include bram_dp_custom_pkg in your higher level RTL to properly instantiate bram_dp_custom.