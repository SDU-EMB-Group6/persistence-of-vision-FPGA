Compilation Instructions
------------------------

Follow these instructions for correctly compiling the project

- Open the project file (.xpr file) with vivado
- Open the block design
- Open the elaborated design
- Go to File > Import > Import I/O ports. Once in the browser, open the .xdc
file at <project-dir>/persistence-of-vision.srcs/constrs_1/new/
- Save again the constraints file (preferably with the same name). This step is
necessary, as Vivado does not recognise the imported file, only the one saved
from the local project.
- Generate the bitstream

Programming the FPGA and Setting-up the processor
=================================================

After generating generating the bitstream, it has to be sent to the FPGA, in
order to make it work. Moreover, the processor has to be initialized, otherwise
there can be problems with the clock signal, as it goes through the processor.

The FPGA can be programmed in 2 different ways i.e. using the Vivado interface,
or by using the Vivado SDK. As the SDK has to be used as well for setting up the
processor, we will describe the instructions for doing the whole process with
it:

- After generating the bitstream, go to File > Export > Export Hardware. Select
the "include bitstream" option and keep the default directory.
- Launch the SDK. Go to Xilinx Tools > Program FPGA, and accept default options.
- Run a "Hello world" application on the processor. Right click in the project,
and select Run As > Launch on Hardware (System Debugger).