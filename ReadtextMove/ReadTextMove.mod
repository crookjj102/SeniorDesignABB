MODULE ReadTextMove
    !   This module reads text from the target .txt file and moves to the points contained therein.
    !   Joshua Crook CM 1601   1-29-2016.
    VAR iodev pointsFile;
    PERS num paintHeight:=10;
    PERS num canvasHeight:=0;
    PERS num PAINT_MAX_DIST:=50;

    VAR num XTGT:=0;
    ! X target
    VAR num YTGT:=0;
    ! Y Target

    VAR num lastX:=0;
    VAR num lastY:=0;

    VAR string STRX;
    VAR string STRY;
    VAR string STRColor;

    VAR bool okX;
    VAR bool okY;
    VAR bool Skip;

    VAR num vX;
    VAR num vY;

    VAR num angleX;
    VAR num angleY;
    !measured in degrees from vertical.
    VAR num brushAngle:=10;

    VAR num vectorMag;
    VAR num distanceTravelled;

    PERS robtarget overBlue;
    PERS robtarget blue;

    VAR num CaseHit;


    VAR orient ZeroZeroQuat:=[0.7071067811,0,0.7071067811,0];
    !vertical for paint can, etc.
    VAR orient paintStrokeQuat:=[0.7071067811,0,0.7071067811,0];
    !will change according to paintstroke vector.
    PERS num SF:=0.5;
    PERS num brushLength:=200;
    PERS num XOffset:=200;
    PERS num YOffset:=-150;
    PERS tooldata paintBrush:=[TRUE,[[87,0,146],[1,0,0,0]],[0.2,[0,0,146],[0,0,1,0],0,0,0]];

    PROC main()
        overBlue:=[[314+brushLength,-216,paintHeight+50],ZeroZeroQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]];
        blue:=[[314+brushLength,-216,paintHeight],ZeroZeroQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]];
        Open "HOME:/DickbuttTesttext.txt",pointsFile\Read;
        distanceTravelled:=0;
        readCoords;
        GotoPaint(STRColor);
        !first dip
        WHILE okX AND okY DO
            ! While we have data points in the file.
            moveToXY XTGT,YTGT;
            readCoords;
        ENDWHILE
        Close pointsFile;
        ! exit.
    ENDPROC

    !   Reads the text file. 
    PROC readCoords()
        STRX:=ReadStr(pointsFile\Delim:=",");
        okX:=StrToVal(STRX,XTGT);
        !End of a line.
        IF STRX=";" THEN
            STRColor:=ReadStr(pointsFile\Delim:=",");
            ! read the X value of the first point in the new line. 
            STRX:=ReadStr(pointsFile\Delim:=",");
            STRY:=ReadStr(pointsFile\Delim:=",");

            okX:=StrToVal(STRX,XTGT);
            okY:=StrToVal(STRY,YTGT);
            XTGT:=(SF*XTGT)+brushLength+XOffset;
            YTGT:=SF*YTGT+YOffset;
            CaseHit:=0;

        ELSEIF okX=FALSE THEN
            !Beginning of a file. 
            STRColor:=STRX;
            STRX:=ReadStr(pointsFile\Delim:=",");
            STRY:=ReadStr(pointsFile\Delim:=",");

            okX:=StrToVal(STRX,XTGT);
            okY:=StrToVal(STRY,YTGT);

            XTGT:=(SF*XTGT)+brushLength+XOffset;
            YTGT:=SF*YTGT+YOffset;
            lastX:=XTGT;
            lastY:=YTGT;
            CaseHit:=1;

        ELSEIF okX=TRUE THEN

            !we've already read the X value and it's not a character for a new line to be drawn. 
            STRY:=ReadStr(pointsFile\Delim:=",");
            okY:=StrToVal(STRY,YTGT);
            XTGT:=(SF*XTGT)+brushLength+XOffset;
            YTGT:=SF*YTGT+YOffset;
            CaseHit:=2;

        ENDIF
        !end of a file. 
        IF (NOT okX) AND (NOT okY) THEN
            MoveL [[LastX,LastY,canvasHeight+30],ZeroZeroQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]],v500,z0,paintBrush;
            MoveL overBlue,v500,fine,paintBrush;
        ENDIF
    ENDPROC

    PROC moveToXY(num XCoord,num YCoord)
        niceStroke;
        ConfL\Off;
        IF distanceTravelled>=PAINT_MAX_DIST OR CaseHit=0 THEN
            !if we've gone maximum distance or we reach the end of a line. 
            GotoPaint(STRColor);
            distanceTravelled:=0;
        ENDIF
        IF NOT (CaseHit=0) THEN
            distanceTravelled:=distanceTravelled+vectorMag;
        ENDIF
        MoveL [[XCoord,YCoord,canvasHeight],paintStrokeQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]],v100,z0,paintBrush;
        lastX:=XTGT;
        lastY:=YTGT;

        ! This moves to point at 100 mm/sec. 
    ENDPROC

    PROC GotoPaint(string colorToPaint)
        !this is currently for blue paint only. 
        ConfL\Off;
        !over target
        MoveL [[LastX,LastY,canvasHeight],paintStrokeQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]],v100,fine,paintBrush;
        MoveL [[LastX,LastY,canvasHeight+30],ZeroZeroQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]],v500,z0,paintBrush;
        IF (colorToPaint="blue") THEN
            !over paint
            MoveL overBlue,v500,z0,paintBrush;
            !into paint
            MoveL blue,v100,fine,paintBrush;
            !over paint
            MoveL overBlue,v500,z0,paintBrush;
        ENDIF
        !over target
        IF (CaseHit=0) THEN
            lastX:=XTGT;
            lastY:=YTGT;
        ENDIF
        MoveL [[LastX,LastY,canvasHeight+20],paintStrokeQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]],v500,z0,paintBrush;
        MoveL [[LastX,LastY,canvasHeight],paintStrokeQuat,[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]],v100,fine,paintBrush;

    ENDPROC

    PROC niceStrokeQuat()
        !paintstroke vector
        vX:=XTGT-lastX;
        vY:=YTGT-lastY;
        vectorMag:=sqrt(vX*vX+vY*vY);

        angleY:=90+brushAngle;
        !Case to handle new lines. 
        IF CaseHit=0 OR CaseHit=1 THEN
            paintStrokeQuat:=ZeroZeroQuat;

        ELSEIF vX>=0 AND vY>=0 THEN
            !PUSH
            paintStrokeQuat:=OrientZYX(ATan2(vY,vX),angleY,0);
        ELSEIF vX>=0 AND vY<=0 THEN
            !PUSH
            paintStrokeQuat:=OrientZYX(ATan2(vY,vX),angleY,0);
        ELSEIF vX<=0 AND vY>=0 THEN
            !PULL
            paintStrokeQuat:=OrientZYX(180-ATan2(vY,vX),180-angleY,0);
        ELSEIF vX<=0 AND vY<=0 THEN
            !PULL
            paintStrokeQuat:=OrientZYX(180-ATan2(vY,vX),angleY,0);
        ENDIF
    ENDPROC
!   not really a nice stroke.
    PROC niceStroke()
        vX:=XTGT-lastX;
        vY:=YTGT-lastY;
        vectorMag:=sqrt(vX*vX+vY*vY);
        paintStrokeQuat:=ZeroZeroQuat;
    ENDPROC
ENDMODULE