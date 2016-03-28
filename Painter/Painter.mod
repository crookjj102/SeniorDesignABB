MODULE Painter
    !***********************************************************
    !
    ! Module:  Painter
    !
    ! Description:
    !   Painting module for the ABB IRB120 
    !
    ! Author: drongla, crookjj, doughezj, horvegc
    !
    ! Version: 0.1
    !
    !***********************************************************
    
    
  

    ! *** Constants ***
    ! Commonly Tweaked declarations
    CONST num brushLength:=200;
    CONST num paintHeight:=10;
    CONST num cleanerHeight:=100; ! TODO: actually find out what this is. 
    !CONST num dryerHeight:=100; ! TODO: actually find out what this is. 
    CONST num canvasHeight:=0;
    CONST num PAINT_MAX_DIST:=50;
    ! Canvas size Declarations
    ! * The largest usable square area the robot can draw in is 500mm wide by 150mm tall
    ! * This is a rectangular large canvas, about 19.6" by 9.8"
    CONST num canvasXmin:=400;
    CONST num canvasXmax:=650;
    CONST num canvasYmin:=-250;
    CONST num canvasYmax:=250;  
    ! Used in the conversion of pixels to mm on the canvas
    CONST num XOffset:=260;
    CONST num YOffset:=-150;
    ! Scaling factor for when we load an image (Default 0.5)
    VAR num SF:=0.5;
    ! Orientation constants
    VAR orient ZeroZeroQuat:=[0.7071067811,0,0.7071067811,0];    
       
    ! Describes the paintbrush location. TODO: verify with metric calipers. 
    PERS tooldata paintBrush:=[TRUE,[[87,0,146],[1,0,0,0]],[0.2,[0,0,146],[0,0,1,0],0,0,0]];
    ! *** Variables ***  
    VAR iodev iodev1;
    ! Store image size, in pixels
    VAR num sizeX;
    VAR num sizeY;
    VAR num XTGT:=0;
    ! X target
    VAR num YTGT:=0;
    ! Y Target
    VAR num lastX:=0;
    VAR num lastY:=0;
    ! processing coordinates
    VAR num tX;
    VAR num tY;
    !

    VAR num vX;
    VAR num vY;

    VAR num vectorMag;

    ! Locations of the painting targets. 
    VAR orient paintStrokeQuat:=[0.7071067811,0,0.7071067811,0]; 
    ! Change these in procedure: initializeColors
    VAR robtarget overA;
    VAR robtarget colorA;

    VAR robtarget overB;
    VAR robtarget colorB;

    VAR robtarget overC;
    VAR robtarget colorC;

    VAR robtarget overD;
    VAR robtarget colorD;

    VAR robtarget overE;
    VAR robtarget colorE;

    VAR robtarget overF;
    VAR robtarget colorF;

    VAR robtarget overClean;
    VAR robtarget clean;
    !    
    VAR bool newStroke;
    ! UI Variables/Constants
    VAR btnres answer;
    CONST string my_message{5}:= ["Please check and verify the following:","- The serial cable is connected to COM1 of the controller", "- The PC is connected to the serial calbe","- BobRoss is running on the PC","- BobRoss has opened the serial channel on the PC"];
    CONST string my_buttons{2}:=["Ready","Abort"];
    ! First-loop flags
    VAR bool firstTimeRun := TRUE;
    VAR string currentColor:= "A";
    
    !***********************************************************
    !
    ! Procedure main
    !
    !   This is the entry point of your program
    !
    !***********************************************************
    PROC main()
        
        answer:= UIMessageBox(
            \Header:="Pre-Paint Com Checks"
            \MsgArray:=my_message
            \BtnArray:=my_buttons
            \Icon:=iconInfo);
        IF answer = 1 THEN
            ! Operator said ready
            paintProgram;
!        ELSEIF answer = 2 THEN 
!            ! operator said abort
!        ELSE 
!            ! no such case defined. 
        ENDIF 
        

    ENDPROC
    
    !***********************************************************
    !
    ! Procedure paintProgram
    !
    !   This initializes our program and immediately looks for SIZE to be set by serial commands. 
    !
    !***********************************************************    
    PROC paintProgram()
        LOCAL VAR bool result;
        LOCAL VAR string response;
        LOCAL VAR num splitnum;
        LOCAL VAR string directive;
        LOCAL VAR string params;
        LOCAL VAR num endTokenPos;
        initializeColors;
        Open "COM1:", iodev1 \Bin;
        ClearIOBuff iodev1;
        WaitTime 0.1;
        WriteStrBin iodev1, "READY\0A";
        response := ReadStr(iodev1\RemoveCR\DiscardHeaders);
        ! Slice this up into directive and parameters
        endTokenPos:=StrFind(response, 1, ";");
        IF endTokenPos > StrLen(response) THEN
            ErrLog 4800, "Command Error", "Missing ';' terminator in message",response,"-","-";
            TPWrite "Command Error: Missing semicolon to terminate command";
        ELSE
            response:=StrPart(response,1, endTokenPos-1); ! trim string to ignore end token.
        ENDIF
        splitNum := StrFind(response, 1, ":");
        ! note: StrPart( string, startIndexInclusive, endIndexInclusive)
        directive := StrPart(response, 1, splitNum - 1); ! We don't care about the ':'
        params := StrPart(response, splitNum+1, Strlen(response));
        
        IF response = "SIZE" THEN
            ! Expected 'response' to be SIZE:X400,Y200;
            WriteStrBin iodev1, "Thanks for size! " + params + "\0A";
            result:=readSize(params);
            IF result = TRUE THEN
                ! do other stuff! WoohoooooooooO!OOO!O!O!O!OO!O!O!O
                WriteStrBin iodev1, "OK\0A";
                result:=paintLoop;  ! When this is called for the first time, it will be after obtaining the image size. 
            ELSE 
                WriteStrBin iodev1, "FAILED\0A";
            ENDIF 
        ELSEIF response = "COORD" THEN
            ! Expected 'response' to be COORD:X200,Y201
            WriteStrBin iodev1, "Thanks for coord! " + params + "\0A";
        ELSE
            ! Response could have been NEXT: or SWAP:A or END:
            WriteStrBin iodev1, "Thanks for nothing! " + directive + "\0A";
        ENDIF
        Close iodev1;
    ENDPROC

    !***********************************************************
    !
    ! Procedure initializeColors
    !
    !   This sets up all targets in the program. 
    !
    !***********************************************************
    PROC initializeColors()
        overA:=[[514+brushLength,75,paintHeight+50],ZeroZeroQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]];
        colorA:=[[514+brushLength,75,paintHeight],ZeroZeroQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]];

        overB:=[[514+brushLength,50,paintHeight+50],ZeroZeroQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]];
        colorB:=[[514+brushLength,50,paintHeight],ZeroZeroQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]];

        overC:=[[514+brushLength,25,paintHeight+50],ZeroZeroQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]];
        colorC:=[[514+brushLength,25,paintHeight],ZeroZeroQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]];

        overD:=[[514+brushLength,0,paintHeight+50],ZeroZeroQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]];
        colorD:=[[514+brushLength,0,paintHeight],ZeroZeroQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]];

        overE:=[[514+brushLength,-25,paintHeight+50],ZeroZeroQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]];
        colorE:=[[514+brushLength,-25,paintHeight],ZeroZeroQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]];

        overF:=[[514+brushLength,-50,paintHeight+50],ZeroZeroQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]];
        colorF:=[[514+brushLength,-50,paintHeight],ZeroZeroQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]];

            ! TODO: Accurately describe these locations. 
        overClean:=[[514+brushLength,-50,cleanerHeight+brushLength],ZeroZeroQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]];
        clean:=[[514+brushLength,-50,cleanerHeight],ZeroZeroQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]];
        overDryer:=[[514+brushLength,-50,cleanerHeight+brushLength],ZeroZeroQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]];
        dryer:=[[514+brushLength,-50,cleanerHeight],ZeroZeroQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]];
        
    ENDPROC
    !***********************************************************
    !
    ! function processCoordinates(string)
    !           String: "x:123,y:456'
    !           Returns TRUE or FALSE if it passes or fails. 
    !
    !   This takes a string and puts the x, y into globals tX and tY
    !
    !***********************************************************
    FUNC bool processCoordinates(string parameters)
        ! exampleParams are X:230,Y:170;
        ! note: it may or may not contain a semicolon
        ! Slice this up into directive and parameters
        
        LOCAL VAR num splitNum := StrFind(parameters, 1, ",");
        ! note: StrPart( string, startIndexInclusive, endIndexInclusive)
        LOCAL VAR bool ok;
        LOCAL VAR bool result := TRUE;
        LOCAL VAR string dA := StrPart(parameters, 1, splitNum - 1); ! Should be X:230 - We don't care about the ','
        LOCAL VAR string dB ;
        LOCAL VAR num dataIndex := StrFind(dA, 1, ":"); ! finding the ':' in X:230
        LOCAL VAR num dAtype;
        LOCAL VAR num dBtype;
        LOCAL VAR num dAval;
        LOCAL VAR num dBval;
        IF dataIndex < StrLen(dA) THEN
            ! continue processing
            dAtype := StrPart(dA, 1, 1); ! Should be X
            ok:=StrToVal(StrPart(dA, 3, StrLen(dA)), dAval); ! should trim the X: from X:230 and parse 230
            IF ok = TRUE THEN 
                IF dAtype = "X" OR dAtype = "x" THEN                
                    tX:=dAval;
                ELSE 
                    tY:=dAval;
                ENDIF 
            ELSE 
                ! throw error!
                ErrLog 4800, "Coord Error", "Mangled coordinates in first pair","-","-","-";
                TPWrite "Bad coordinates in the file: mangled first in pair";
                result := FALSE;
            endif
            dB:= StrPart(parameters, splitNum + 1, StrLen(parameters)); ! should be Y:170
            dataIndex := StrFind(dB, 1, ":"); ! finding the ':' in Y:170
            
            IF dataIndex < StrLen(dB) THEN 
                            ! continue processing
                dBtype := StrPart(dB, 1, 1); ! Should be X
                ok:=StrToVal(StrPart(dB, 3, StrLen(dB)), dBval);
                IF ok = TRUE THEN 
                    IF dBtype = "X" OR dBtype = "x" THEN
                        IF dAtype = "Y" OR dAtype = "y" THEN 
                        tX:=dBval;
                        ok := TRUE;
                        ELSE
                            ok := FALSE;
                        ENDIF 
                    ELSE 
                        IF dAtype = "X" OR dAtype = "x" THEN 
                        tY:=dBval;
                        ok := TRUE;
                        ELSE 
                            ok:= FALSE;
                        ENDIF 
                    ENDIF 
                ELSE 
                    ! throw error!
                ErrLog 4800, "Coord Error", "Mangled coordinates in second pair","-","-","-";
                TPWrite "Bad coordinates in the file: mangled second in pair";
                result := FALSE;
                ok:= TRUE;
                endif
                ! check and see if OK changed to false again.
                IF ok = FALSE THEN
                    ErrLog 4800, "Coord Error", "Multiple X or Y coords recieved","Expected to see coordinates of the format X:###,Y:###","Saw two declarations of X or Y","-";
                    TPWrite "Bad coordinates in the file: duplicated";
                    result := FALSE;
                ENDIF 
            ELSE
                ! we have a problem. X or Y not found
                    ErrLog 4800, "Coord Error", "Missing X or Y coords","Expected to see coordinates of the format X:###,Y:### ","Saw missing declaration of X or Y in second of pair","Missing Second pair declaration";
                    TPWrite "Bad coordinates in the file: missing second pair dec";
                    result := FALSE;
            ENDIF 
        ELSE 
            ! we have a problem. Throw an error. 
            ErrLog 4800, "Coord Error", "Missing X or Y coords","Expected to see coordinates of the format X:###,Y:### ","Saw missing declaration of X or Y in first of pair","Missing First pair declaration";
            TPWrite "Bad coordinates in the file: missing first pair dec";
            result := FALSE;
        ENDIF
        RETURN result;
    endfunc 
    
    !***********************************************************
    !
    ! function result readSize(string)
    !           String: "x:123,y:456"
    !           Returns TRUE or FALSE if it passes or fails. 
    !
    !   Reads the size off the passed file
    !
    !***********************************************************    
    FUNC bool readSize(string parameters)   
        
        LOCAL VAR bool result := processCoordinates(parameters);
        
        IF result = TRUE THEN
            ! are we over the size constraints and in need of a scaling factor?
            IF (sizeX > (canvasXmax-canvasXmin)) OR (sizeY > (canvasYmax-canvasYmin))THEN
                ! the Y proportion should be the scaling factor, as it was the smaller number
                IF ((canvasXmax-canvasXmin)/sizeX) > ((canvasYmax-canvasYmin)/sizeY) THEN
                    SF:=(canvasYmax-canvasYmin)/sizeY;
                ELSE
                    SF:=(canvasXmax-canvasXmin)/sizeX;
                ENDIF
                    
            ENDIF
                
        ELSE
            ErrLog 4800, "Data Error", "The canvas size data was malformed","","","You should have seen other errors before this.";
        ENDIF
        
        RETURN result;
    ENDFUNC 
    
    !***********************************************************
    !
    ! function result paintLoop()
    !           Returns FALSE on completion
    !
    !   loops and reads from the serial channel, and passes the commands to subroutines.
    !
    !***********************************************************    
    FUNC bool paintLoop()
        LOCAL VAR bool loop := TRUE;
        LOCAL VAR string response;
        LOCAL VAR num splitNum;
        LOCAL VAR string directive;
        LOCAL VAR string params;
        LOCAL VAR num distanceTravelled := 0;
        WHILE loop = TRUE DO
            response := ReadStr(iodev1\RemoveCR\DiscardHeaders);
            ! Slice this up into directive and parameters
            splitNum := StrFind(response, 1, ":");
            ! note: StrPart( string, startIndexInclusive, endIndexInclusive)
            IF splitNum = StrLen(response) THEN 
                directive := StrPart(response, 1, splitNum - 1); ! We don't care about the ':'
                
                loop:=directiveNoParams(directive);
                
            ELSEIF splitNum < StrLen(response) THEN 
                directive := StrPart(response, 1, splitNum - 1); ! We don't care about the ':'
                params := StrPart(response, splitNum+1, Strlen(response));  
                
                loop:= directiveWithParams(directive, params);
            ELSE 
                ErrLog 4800, "Command Error", "Missing ';' terminator in message",response,"-","-";
                TPWrite "Command Error: Missing semicolon to terminate command";
                WriteStrBin iodev1, "FAILED\0A";
                loop:= FALSE;
            ENDIF 
            
        ENDWHILE
        
        RETURN loop;
    ENDFUNC
    !***********************************************************
    !
    ! function result directiveNoParams(string)
    !           String: "NEXT" or "END"
    !           Returns TRUE or FALSE if it passes or fails. 
    !
    !   does the asssociated directive and echoes back what it has done.
    !
    !***********************************************************    
    FUNC bool directiveNoParams(string directive)
        IF directive = "NEXT" THEN 
            WriteStrBin iodev1, "NEXT\0A";
            newStroke:=TRUE;
            
        ELSEIF directive = "END" THEN 
            WriteStrBin iodev1, "END\0A";
            moveToFinish;
            RETURN FALSE;
        ELSE 
            ErrLog 4800, "Command Error", "Unknown Command",directive,"-","-";
            TPWrite "Command Error: Unknown Command";
            WriteStrBin iodev1, "FAILED\0A";
            RETURN FALSE;
        ENDIF 
            
    ENDFUNC
    !***********************************************************
    !
    ! function result directiveWithParams(directive, params)
    !           directive: "COORD" or "SWAP"
    !           params: "X:NUM,Y:NUM" or a character in range A-F inclusive.
    !           Returns TRUE or FALSE if it passes or fails. 
    !
    !   does the asssociated directive and echoes OK or FAILED
    !
    !***********************************************************  
    FUNC bool directiveWithParams(string directive, string params)
        LOCAL VAR bool result := processCoordinates(params);
        LOCAL VAR bool testCheck:=true;
        IF directive = "COORD" THEN 
            IF firstTimeRun THEN
                GotoPaint(currentColor);
                firstTimeRun := FALSE; 
            endif
            testCheck:=checkForBadPoints( tX,tY);
            XTGT:=(SF*tX)+canvasXmin;
            YTGT:=(SF*tY)+canvasYmin;
            moveToXY XTGT,YTGT;
            ! After moving, update our case. This ensures that we are starting new strokes
            ! correctly if NEXT was called before this
            newStroke:=FALSE;
            IF testCheck = TRUE THEN 
            WriteStrBin iodev1, "OK\0A";
            RETURN TRUE;
            ELSE 
                WriteStrBin iodev1, "FAILED\0A";
                RETURN FALSE;
            ENDIF 
        ELSEIF directive = "SWAP" THEN 
               currentColor := params;
               !TODO: clean here!
               GotoPaint(currentColor);
               WriteStrBin iodev1, "SWAP\0A";
               RETURN TRUE; 
        ELSE 
            ErrLog 4800, "Command Error", "Unknown Command",directive,params,"-";
            TPWrite "Command Error: Unknown Command";
            WriteStrBin iodev1, "FAILED\0A";
            RETURN FALSE; 
        ENDIF 
     RETURN FALSE;
    ENDFUNC
    
    !***********************************************************
    !
    ! function result checkForBadPoints(x, y)
    !           x, y: points within the canvas
    !           
    !           Returns TRUE or FALSE if it passes or fails. 
    !
    !   ensures that the point is within the defined canvas. 
    !
    !*********************************************************** 
    func bool checkForBadPoints(num Xcoord, num Ycoord)
        IF (Xcoord>sizeX) OR (Ycoord>sizeY) THEN
            ErrLog 4800, "Coord Error", "One of the coordinates is outside expected bounds","Coordinates larger than image size are not allowed","-","-";
            TPWrite "Bad coordinates in the file: outside expected bounds";
            MoveL overA,v500,fine,paintBrush;
            Stop;
            RETURN FALSE; 
        ENDIF
        IF  (Xcoord<0) OR (Ycoord<0) THEN
            ErrLog 4800, "Coord Error", "Negative Coordinates are not allowed.","-","-","-";
            TPWrite "Bad coordinates in the file: outside expected bounds";
            MoveL overA,v500,fine,paintBrush;
            Stop;
            RETURN FALSE;
        ENDIF
            RETURN TRUE;
    ENDFUNC 
    !***********************************************************
    !
    ! procedure  moveToXY(x, y)
    !           x, y: points within the canvas
    !           
    !
    !   Moves to points and goes to paint if the end of a stroke is reached
    !
    !***********************************************************
    PROC moveToXY(num XCoord,num YCoord)
        niceStroke;
        ConfL\Off;
        IF distanceTravelled>=PAINT_MAX_DIST OR newStroke=TRUE THEN
            !if we've gone maximum distance or we reach the end of a line. 
            GotoPaint(currentColor);
            distanceTravelled:=0;
        ENDIF
        IF NOT (newStroke=TRUE) THEN
            distanceTravelled:=distanceTravelled+vectorMag;
        ENDIF
        MoveL [[XCoord,YCoord,canvasHeight],paintStrokeQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]],v100,z0,paintBrush;
        lastX:=XTGT;
        lastY:=YTGT;

        ! This moves to point at 100 mm/sec. 
    ENDPROC
    !***********************************************************
    !
    ! procedure  moveToFinish()
    !          
    !      Moves to a photogenic finishing spot. 
    !
    !***********************************************************
    PROC moveToFinish()
        ! TODO: To be tested. We want to move to a nice parking spot when we are done. 
        MoveL [[0,150,canvasHeight+50],ZeroZeroQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]],v500,z0,paintBrush;
        Stop;
    ENDPROC 
    !***********************************************************
    !
    ! procedure  GotoPaint(paintString)
    !       paintString: a character from A-F inclusive
    !          
    !      Moves and gets paint. If the paint color has changed, clean the brush.
    !
    !***********************************************************
    PROC GotoPaint(string colorToPaint)
        ConfL\Off;
        !over target
        MoveL [[LastX,LastY,canvasHeight],paintStrokeQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]],v100,fine,paintBrush;
        MoveL [[LastX,LastY,canvasHeight+30],ZeroZeroQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]],v500,z0,paintBrush;
        IF (colorToPaint="A") THEN
            !over paint
            MoveL overA,v500,z0,paintBrush;
            !into paint
            MoveL colorA,v100,fine,paintBrush;
            !over paint
            MoveL overA,v500,z0,paintBrush;

        ELSEIF (colorToPaint="B") THEN
            !over paint
            MoveL overB,v500,z0,paintBrush;
            !into paint
            MoveL colorB,v100,fine,paintBrush;
            !over paint
            MoveL overB,v500,z0,paintBrush;
        ELSEIF (colorToPaint="C") THEN
            !over paint
            MoveL overC,v500,z0,paintBrush;
            !into paint
            MoveL colorC,v100,fine,paintBrush;
            !over paint
            MoveL overC,v500,z0,paintBrush;
        ELSEIF (colorToPaint="D") THEN
            !over paint
            MoveL overD,v500,z0,paintBrush;
            !into paint
            MoveL colorD,v100,fine,paintBrush;
            !over paint
            MoveL overD,v500,z0,paintBrush;
        ELSEIF (colorToPaint="E") THEN
            !over paint
            MoveL overE,v500,z0,paintBrush;
            !into paint
            MoveL colorE,v100,fine,paintBrush;
            !over paint
            MoveL overE,v500,z0,paintBrush;
        ELSEIF (colorToPaint="F") THEN
            !over paint
            MoveL overF,v500,z0,paintBrush;
            !into paint
            MoveL colorF,v100,fine,paintBrush;
            !over paint
            MoveL overF,v500,z0,paintBrush;

        ELSEIF (NOT (colorToPaint=lastColor)) THEN
            !NEED TO CLEAN
            MoveL overClean,v500,z0,paintBrush;
            MoveL clean,v100,fine,paintBrush;
            MoveL overClean,v500,z0,paintBrush;
        ENDIF
        !over target
        IF (newStroke=TRUE) THEN
            lastX:=XTGT;
            lastY:=YTGT;
        ENDIF
        MoveL [[LastX,LastY,canvasHeight+20],paintStrokeQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]],v500,z0,paintBrush;
        MoveL [[LastX,LastY,canvasHeight],paintStrokeQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]],v100,fine,paintBrush;
        lastColor:=colorToPaint;
    ENDPROC
    
    !***********************************************************
    !
    ! procedure  niceStroke()
    !       
    !          Access for modifying the quaternion in the future. 
    !
    !***********************************************************
    PROC niceStroke()
        vX:=XTGT-lastX;
        vY:=YTGT-lastY;
        vectorMag:=sqrt(vX*vX+vY*vY);
        ! Actual nice strokes nuked for now. FUTURE: Create actual nice quaternion strokes. 
        paintStrokeQuat:=ZeroZeroQuat;
    ENDPROC
ENDMODULE