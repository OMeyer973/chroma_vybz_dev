import ch.bildspur.postfx.builder.*;
import ch.bildspur.postfx.pass.*;
import ch.bildspur.postfx.*;

import ddf.minim.*;
import ddf.minim.analysis.*;

PostFX fx;

PostFXSupervisor supervisor;
ChromaticAberrationPass chromaticAberrationPass;

//variables to set
int canvasSize = 1000;
int planeSize = 2000;
int nbRows  = 18;
float oscSpeed = 0.03;
float oscAmp = 100;
float squareSize = planeSize/(nbRows-1);
float baseCamSpeed = 5;

float soundBoost = 100;
float hillHeight = 50;
float lineWidth = 4;

//computing variables
boolean chromaticAberration = false;
boolean rolling = true;
float rollAngle = 0;
float currHillHeight = 0;
color hillColor; 
float camPos = 0;
float camSpeed = 0;
float bloomIntensity = 0;
float colorHue = 0;
float colorFactor = 1;

//tabs
Point dispTab[][];
Point posTab[][];
int altInd[][]; //indices des points alternés pour avoir le pic des basses au milieu + un peu de random
Point starPos[][];

Point camRot;
float nbFrames = 0;


//audio computing variables
Minim minim;
AudioInput song;
FFT fft;
float trackIntensity = 0.1;
float maxTrackIntensity = 0.1;
float freqBands[]; //final audio tab containing 8 audio bands
float freqBandsSmooth[]; 

//computing variables, do not modify
int col=255; // color, oscillates over time.

void settings() {
    PJOGL.setIcon("icon.png");

  //size(1080, 720, P3D);
  fullScreen(P3D);
}

void setup()
{
  supervisor = new PostFXSupervisor(this);
  chromaticAberrationPass = new ChromaticAberrationPass(this); 
  
  surface.setTitle("chroma vybz"); 

  surface.setResizable(true);
  colorMode(HSB, 360, 100, 100);

  // always start Minim first!
  minim = new Minim(this);


  fx = new PostFX(this);  
  hillColor = color(100, 50, 50);
  camRot = new Point(0, 0, 0);

  // specify 512 for the length of the sample buffers
  // the default buffer size is 1024
  //song = minim.loadFile("Savant - Vybz - Indica.mp3", 1024);
  song = minim.getLineIn();

  planeSize = 4 * height;
  oscAmp = planeSize /30;
  
  dispTab = new Point[nbRows][nbRows];
  posTab = new Point[nbRows][nbRows];
  altInd = new int[nbRows][nbRows];
  starPos = new Point[nbRows][nbRows/2];

  for (int i = 0; i < nbRows; i++) {  
    for (int j = 0; j < nbRows; j++) {
      dispTab[i][j] = new Point(0, 0, 0);
      posTab[i][j] = new Point(0, 0, 0);
      altInd[i][j] = (2*(i%2)-1)*(i+1)/2+nbRows/2-1;  
      //altInd[i][j] = int(clamp(altInd[i][j]+random(-nbRows*0.15, nbRows*0.15), 0, nbRows-1));  
    
      starPos[i][j/2] = new Point(random(-planeSize, planeSize),random(-planeSize/2, planeSize/2),random(planeSize/20, planeSize));
      }
  }

  freqBands = new float[8];
  freqBandsSmooth = new float[8];

  // an FFT needs to know how
  // long the audio buffers it will be analyzing are
  // and also needs to know
  // the sample rate of the audio it is analyzing
  fft = new FFT(song.bufferSize(), song.sampleRate());
  
}

void draw()
{ 
  squareSize = planeSize/(nbRows-1);
  float cameraZ = ((height/2.0) / tan(PI*60.0/360.0));
  perspective(PI/3, float(width)/float(height), cameraZ/10.0, planeSize*7.0);
  
  background(300,64,10);
  // first perform a forward fft on one of song's buffers
  // I'm using the mix buffer
  fft.forward(song.mix);
  
  keyPressed();

  strokeCap(ROUND);

  trackIntensity = (song.left.level()+song.right.level());
  maxTrackIntensity = max(maxTrackIntensity, trackIntensity);
  maxTrackIntensity = flerp(trackIntensity, maxTrackIntensity, 0.9999);
  //print(maxTrackIntensity+"\n");
  //CONFIIG
  trackIntensity = soundBoost * trackIntensity / maxTrackIntensity;
  currHillHeight = hillHeight / maxTrackIntensity * squareSize;
  
  makePosTab();
  stroke(hillColor);



  translate(width/2, height/2, 0);

  rotateX(PI*0.45);
  cameraFreeLook();


  translate(0, -height*0.8, -width/2);

  
  
  //dessin des collines
  pushMatrix();


    pushMatrix();
    fill(hillColor);
    translate(0,0,0);
    rotateZ(PI/2);
    rect(-50000, -50000, 100000, 100000);
    popMatrix();
    
    translate(0, camPos, 0);

  if (rolling) {
    rollAngle += (trackIntensity*trackIntensity+1)/2000000;
  } else {
    rollAngle = 0;
  }
  for (int k = 0; k < 8; k++) {
      //dessin du fond
    
    
    
    //dessin des étoiles
    strokeWeight(0);
    fill(color(0,0,50+trackIntensity/2)); 
    for (int i = 0; i < nbRows; i++) {  
      for (int j = 0; j < nbRows/2; j++) {
        pushMatrix();
          translate(starPos[i][j].x, starPos[i][j].y, starPos[i][j].z);
          rotateZ(PI/2);
          rect(-3*lineWidth, -3*lineWidth, 5+3*trackIntensity,6*lineWidth);
          rotateX(-PI/2);
          rect(-3*lineWidth, -3*lineWidth, 5+3*trackIntensity,6*lineWidth);
        popMatrix();
      }
    }
    strokeWeight(lineWidth);
    stroke(hillColor);
    fill(230,60,10);
    pushMatrix();
      translate(-planeSize/2+squareSize,0,0);
      
      drawPlane();
      pushMatrix();
        translate(planeSize, 0, 0);
        drawPlane();
      popMatrix();
    popMatrix();
    translate(0, -planeSize, 0);
  }  
  popMatrix();
  
  
  rotateY(PI);  
  /*
  //cieling
   pushMatrix();
   translate(-planeSize/2+squareSize, camPos, -canvasSize*2);
   for (int i = 0; i < 5; i++) {
   drawPlane();
   pushMatrix();
   translate(planeSize, 0, 0);
   drawPlane();
   popMatrix();
   
   translate(0, -planeSize, 0);
   }  
   popMatrix();
   */
  camSpeed += trackIntensity/10;
  camSpeed = flerp(camSpeed, baseCamSpeed, 0.1);
  
  camPos += camSpeed;
  if (camPos-500 > planeSize) {
    camPos = camPos - planeSize;
  }
  


  bloomIntensity = flerp(0, bloomIntensity+trackIntensity, 0.01);
  colorHue = colorHue+0.00000005*pow(trackIntensity*colorFactor,4);
  colorHue = colorHue%360; 
  
  blendMode(SCREEN);
  fx.render()
    .brightPass(0.1)
    .blur(max(30-int(bloomIntensity*12), 0), max(50-int(bloomIntensity*9), 0))
    .compose();  
  blendMode(BLEND);
  if (chromaticAberration) {
    supervisor.render();
    supervisor.pass(chromaticAberrationPass);
    supervisor.compose();
  }
  hillColor = color(1+colorHue, min(30+50*bloomIntensity, 95), min(50+50*bloomIntensity, 95));

  nbFrames++;
}


void keyPressed() {
    //print(key + " key\n");
    if (key == 'H') {
      hillHeight *= 1.06;
    }
   if (key == 'h') {
      hillHeight /= 1.06;
    }
   if (key == 'S') {
      soundBoost *= 1.06;
    }
   if (key == 's') {
      soundBoost /= 1.06;
    }
   if (key == 'W') {
      planeSize *= 1.06;
    }
   if (key == 'w') {
      planeSize /= 1.06;
    }
   if (key == 'C') {
      colorFactor *= 1.06;
    }
   if (key == 'c') {
      colorFactor /= 1.06;
    }
   if (key == 'L') {
      lineWidth *= 1.06;
    }
   if (key == 'l') {
      lineWidth /= 1.06;
    }
   if (key == 'r') {
      rolling = !rolling;
    }
   if (key == 'a') {
      chromaticAberration = !chromaticAberration;
    }
    if (key == ESC) {
      exit();
    }    
    key = ' ';
}

void makePosTab () {
  int nbBand = 0;
  int jump = 0;
  for (int i = 0; i < nbRows; i++) {
    for (int j = 0; j < nbRows; j++) {
      /*
      //por faire du max de random
      altInd[i][j] = (2*(i%2)-1)*(i+1)/2+nbRows/2-1;  
      altInd[i][j] = int(clamp(altInd[i][j]+random(-nbRows*0.15, nbRows*0.15), 0, nbRows-1));  
      */
      dispTab[altInd[i][j]][j].z = flerp(dispTab[altInd[i][j]][j].z, log(fft.getBand(nbBand)+1) * 3 *  log(nbBand+1) /  (nbRows * nbRows) * currHillHeight, 0.05);
      dispTab[altInd[i][j]][j].x = oscAmp*sin(-((i+j)*nbFrames*oscSpeed));
      dispTab[altInd[i][j]][j].y = oscAmp*sin(-((i-j)*nbFrames*oscSpeed));

      posTab[i][j].x = squareSize * i - planeSize/2 + oscAmp*sin(((i+j)*2*PI/nbRows+nbFrames*oscSpeed));
      posTab[i][j].y = squareSize * j - planeSize/2 + oscAmp*sin(((i-j)*2*PI/nbRows+nbFrames*oscSpeed));
      posTab[i][j].z = dispTab[i][j].z;

      nbBand += 1+jump;
    }
    jump = i/6; //on saute de + en plus de fréquences pour en avoir mois dans les aigues
  }

  for (int i = 0; i < nbRows; i++) {
    posTab[i][nbRows-1].x = posTab[i][0].x;
    posTab[i][nbRows-1].y = posTab[i][0].y + squareSize * (nbRows-1);
    posTab[i][nbRows-1].z = posTab[i][0].z;
    posTab[nbRows-1][i].x = posTab[0][i].x + squareSize * (nbRows-1);
    posTab[nbRows-1][i].y = posTab[0][i].y;
    posTab[nbRows-1][i].z = posTab[0][i].z;
  }
}

void cameraFreeLook () { 
  camRot.x = flerp(camRot.x, camRot.x+(noise(nbFrames/80)-0.5)*0.1, 0.1);
  camRot.x /= (1+trackIntensity*0.001);
  rotateX(camRot.y);
  camRot.y = flerp(camRot.y, camRot.y+(noise(nbFrames/80)-0.5)*0.1, 0.1);
  camRot.y /= (1+trackIntensity*0.001);
  
  rotateY(camRot.y+PI/6+rollAngle);
  camRot.z = flerp(camRot.z, camRot.z+(noise(nbFrames/80)-0.5)*0.1, 0.1);
  camRot.z /= (1+trackIntensity*0.0001);
  rotateZ(camRot.z+0.1);
}

void drawPlane () {
  beginShape(TRIANGLES);
  for (int i = 0; i < nbRows; i++) {
    for (int j = 0; j < nbRows; j++) {
      setVertex(posTab[i][j]);
      setVertex(posTab[min(i+1, nbRows-1)][j]);
      setVertex(posTab[min(i+1, nbRows-1)][min(j+1, nbRows-1)]);

      setVertex(posTab[i][j]);
      setVertex(posTab[i][min(j+1, nbRows-1)]);
      setVertex(posTab[min(i+1, nbRows-1)][min(j+1, nbRows-1)]);
    }
  }
  endShape();
}

//lerp on floats
float flerp(float a, float b, float f) 
{
  return (a * (1.0 - f)) + (b * f);
}

float clamp(float a, float b, float c) {
  return min(max(a, b), c);
}


class Point {
  float x;
  float y;
  float z;
  Point(float x, float y, float z) {
    this.x = x;
    this.y = y;
    this.z = z;
  }
  void setXY(float x, float y, float z) {
    this.x = x;
    this.y = y;
    this.z = z;
  }
}

void drawFromPoints(Point a, Point b) {
  line(a.x, a.y, b.x, b.y);
}

void setVertex(Point p) {
  vertex(p.x, p.y, p.z);
}


void stop()
{
  //song.close();
  minim.stop();

  super.stop();
}