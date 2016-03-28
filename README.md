# SeniorDesignABB
This is for Andrew Conru's Robot Artist project at Rose-Hulman Institute of technology. 
The goal of this project is to paint pictures using oil paints and an industrial robot.
This is the RAPID code that runs on the ABB IRB120 robot. The intent is to have a 
computer decide where the robot is to move. The points are communicated over (synchronous)serial 
(text file for debugging) and contain the color, x and y positions. 
The overall size of the image is communicated in the beginning of the message and autoscaled 
to the robot's painting area. 
The robot determines (based on experimental data) when it should retrieve paint of 
the current color. The length of a stroke that can be laid without new paint is about 50 mm. 

This portion of the project is developed in ABB RAPID in the RobotStudio environment. 
