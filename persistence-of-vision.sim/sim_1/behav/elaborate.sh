#!/bin/bash -f
xv_path="/opt/Xilinx/Vivado/2017.2"
ExecStep()
{
"$@"
RETVAL=$?
if [ $RETVAL -ne 0 ]
then
exit $RETVAL
fi
}
ExecStep $xv_path/bin/xelab -wto 97a92e546d7641ac83d2f9c67464259c -m64 --debug typical --relax --mt 8 -L xil_defaultlib -L secureip -L xpm --snapshot TB_leds_controller_behav xil_defaultlib.TB_leds_controller -log elaborate.log
