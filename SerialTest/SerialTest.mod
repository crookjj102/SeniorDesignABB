MODULE SerialTest
    !***********************************************************
    !
    ! Module:  SerialTest
    !
    ! Description:
    !   <Insert description here>
    !
    ! Author: drongla
    !
    ! Version: 1.0
    !
    !***********************************************************
    
    
    !***********************************************************
    !
    ! Procedure main
    !
    !   This is the entry point of your program
    !
    !***********************************************************
    VAR iodev terminal;
    PROC main()
        !Add your code here
        Open "COM1:", terminal \Bin;

        WriteStrBin terminal, "This is a message to the printer\0D";

        Close terminal;

    ENDPROC
ENDMODULE