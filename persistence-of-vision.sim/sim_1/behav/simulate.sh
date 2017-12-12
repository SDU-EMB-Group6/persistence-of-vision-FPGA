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
ExecStep $xv_path/bin/xsim TB_leds_controller_behav -key {Behavioral:sim_1:Functional:TB_leds_controller} -tclbatch TB_leds_controller.tcl -log simulate.log
