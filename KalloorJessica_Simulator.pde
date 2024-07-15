// Import Necessary Libraries
import guru.ttslib.*;
import beads.*;
//import org.jaudiolibs.beads.*;
import java.util.*;
import controlP5.*;

// Global Variables
ControlP5 p5;
TextToSpeechMaker ttsMaker;

JSONArray cadenceData;
JSONArray heartRateData;
JSONArray gaitPatternData;
PImage Navigation;

WavePlayer wavePlayer;
SamplePlayer simulatorStart;
SamplePlayer toggle;
SamplePlayer unToggle;
SamplePlayer cadenceTick;
SamplePlayer heartRateBeep;
SamplePlayer gaitPatternIntensity;
SamplePlayer strideLengthSynth;

Slider paceSlider;
Slider gaitPatternSlider;
Knob cadenceKnob;
Knob heartRateKnob;
Knob testKnob;

float cadenceValue;
float heartRateValue;
float gaitPatternValue;
float targetHeartRate;
float targetPace;
float GaitPatternValue;
float StrideLengthValue;
float velocity;
float increment = 0.01;
int framerate = 1000;

boolean enableCadence = true;
boolean enableHeartRate = true;
boolean enableGaitPattern = true;
boolean enableStrideLength = true;
boolean enableGPS = true;
boolean cadenceAlert = true;
boolean heartRateAlert = true;
boolean gaitPatternAlert = true;
boolean toggleFilter = true;
boolean toggleDemoCondition = false;

Button Cadence;
Button GaitPattern;
Button HeartRate;
Button StrideLength;

Glide masterGainGlide;
Glide toggleGlide;
Glide cadenceGlide;
Glide heartRateGlide;
Glide gaitPatternGlide;
Glide strideLengthGlide;
Glide paceGlide;
Glide filterGlide;

Gain masterGain;
Gain simulatorGain;
Glide simulatorGainGlide;
BiquadFilter filter;
Reverb reverb;

String eventJSON1 = "Cadence.json";
String eventJSON2 = "Heart_rate.json";
String eventJSON3 = "Gait_pattern.json";
String NavigationTTS;
String heartRateStatus;
String gaitPatternI;


NotificationServer server;
ArrayList<Notification> notifications;
NotificationListener notificationListener;

// UI/Simulator Setup
void setup() {
  size(800, 600);
  p5 = new ControlP5(this);
  ac = new AudioContext(); // defined in helper functions; created using Beads library
  
  
  server = new NotificationServer();
  server.addListener(notificationListener);

  toggle = getSamplePlayer("Toggle.wav");
  unToggle = getSamplePlayer("Untoggle.wav");
  cadenceTick = getSamplePlayer("Cadence.wav");
  heartRateBeep = getSamplePlayer("Heart_rate.wav");
  gaitPatternIntensity = getSamplePlayer("Gait_pattern.wav");
  strideLengthSynth = getSamplePlayer("Stride_length.wav"); // non-intrusive seamless loop
  simulatorStart = getSamplePlayer("Simulator_start.wav");

  toggle.pause(true);
  unToggle.pause(true);
  cadenceTick.pause(true);
  heartRateBeep.pause(true);
  gaitPatternIntensity.pause(true);
  strideLengthSynth.pause(true);

  Navigation = loadImage("Navigation.png");
  cadenceData = loadJSONArray("Cadence.json"); 
  heartRateData = loadJSONArray("Heart_rate.json");
  gaitPatternData = loadJSONArray("Gait_pattern.json");
  
  cadenceTick.setLoopType(SamplePlayer.LoopType.LOOP_FORWARDS);
  heartRateBeep.setLoopType(SamplePlayer.LoopType.LOOP_FORWARDS);
  gaitPatternIntensity.setLoopType(SamplePlayer.LoopType.LOOP_FORWARDS);
  strideLengthSynth.setLoopType(SamplePlayer.LoopType.LOOP_FORWARDS);

  // Volume properties
  masterGainGlide = new Glide(ac, 1.0, 500);
  masterGain = new Gain(ac, 1, masterGainGlide);

  filterGlide = new Glide(ac, 10.0, 0.5f);
  filter = new BiquadFilter(ac, BiquadFilter.LP, filterGlide, 0.5f);
  filter.setFrequency(1000); // 1000 -> cutoff
  reverb = new Reverb(ac);

  cadenceGlide = new Glide(ac, 1.0, 10);
  cadenceTick.setRate(cadenceGlide);

  heartRateGlide = new Glide(ac, 1.0, 10);
  heartRateBeep.setRate(heartRateGlide);

  gaitPatternGlide = new Glide(ac, 1.0, 10);
  gaitPatternIntensity.setRate(gaitPatternGlide);

  strideLengthGlide = new Glide(ac, 1.0, 10);
  strideLengthSynth.setRate(strideLengthGlide);

  paceGlide = new Glide(ac, 1.0, 10);
  ttsMaker = new TextToSpeechMaker();

  toggleGlide = new Glide(ac, 1.0, 1);
  toggle.setRate(toggleGlide);
  toggleGlide.setValue(3);

  // Set up the WavePlayer with a sine waveform
  float frequency = 440.0;
  wavePlayer = new WavePlayer(ac, frequency, Buffer.SINE);
  wavePlayer.pause(true);

  // add inputs to gain and ac
  masterGain.addInput(reverb);
  masterGain.addInput(cadenceTick);
  masterGain.addInput(heartRateBeep);
  masterGain.addInput(gaitPatternIntensity);
  masterGain.addInput(strideLengthSynth);

  ac.out.addInput(masterGain);
  ac.out.addInput(simulatorStart);
  ac.out.addInput(toggle);
  ac.out.addInput(unToggle);
  ac.out.addInput(cadenceTick);
  ac.out.addInput(heartRateBeep);
  ac.out.addInput(gaitPatternIntensity);
  ac.out.addInput(strideLengthSynth);
  ac.out.addInput(wavePlayer);

  // User Interface
  ConstructUI();
  ac.start();
}

// controls overall volume of audio sonifications
public void MasterGainSlider(float value) {
  masterGainGlide.setValue(value/100);
}

public void GaitPatternSlider(float value) {
  wavePlayer.setFrequency(value/60);
  filter.setFrequency(value/500);
}

// control frequency of runner cadence
public void SetTargetCadence(float value) {
  cadenceGlide.setValue(value/60.0f); // SPM
  // note; have gaitPattern be its own method, dont augment it with cadence.
  // gaitPatternGlide.setValue(value/30.0f); // SPM
}

// control frequency of runner heart rate
public void SetTargetHeartRate(float value) {
  heartRateGlide.setValue(value/60.0f); // BPM
}

// value -> number in seconds
public void setTargetPace(float value) {
  paceGlide.setValue(value/60.0f); //output in minutes per mile;
}

// stride length (feet) =  velocity / (cadence/60)
public void setStrideLength() {
  velocity = 60.0f/paceSlider.getValue() * 60;
  StrideLengthValue = velocity / (cadenceKnob.getValue()/60);
  // a function of velocity, pace, and cadence in feet
  strideLengthGlide.setValue(1/(StrideLengthValue/2.5)); // arbitrary value
}

public String getGaitPatternIntensity() {
  if (!enableGaitPattern && gaitPatternSlider.getValue() < 4000) {
    return "Freezing";
  } else if (!enableGaitPattern && gaitPatternSlider.getValue() >= 4000 &&
    gaitPatternSlider.getValue() <= 10000) {
    return "Shuffling";
  } else if (!enableGaitPattern && gaitPatternSlider.getValue() > 10000) {
    return "Normal";
  } else {
    return "N/A";
  }
}

public void toggleCadence() {
  enableCadence = !enableCadence;
  if (!enableCadence) {
    toggle.start(0);
    cadenceTick.pause(false);
  } else {
    unToggle.start(0);
    cadenceTick.pause(true);
  }
}

public void toggleHeartRate() {
  enableHeartRate = !enableHeartRate;
  if (!enableHeartRate) {
    toggle.start(0);
    heartRateBeep.pause(false);
  } else {
    unToggle.start(0);
    heartRateBeep.pause(true);
  }
}

public void toggleStrideLength() {
  if (enableStrideLength) {
    toggle.start(0);
    strideLengthSynth.pause(false);
  } else {
    unToggle.start(0);
    strideLengthSynth.pause(true);
  }
  enableStrideLength = !enableStrideLength;
}

public void toggleGPS() {
  if (enableGPS) {
    toggle.start(0);
    ttsExamplePlayback("GPS Enabled");
  } else {
    unToggle.start(0);
    ttsExamplePlayback("GPS Disabled");
  }
  enableGPS = !enableGPS;
}

public void recommendNavigation() {
  if (enableGPS) {
    ttsExamplePlayback("Please enable GPS First");
  } else {
    toggle.start(0);
    ttsExamplePlayback("Hello, I am Kevin and I will be helping you today" +
      "Begin your Pi Mile Walk at Georgia Institute of Technology at the North Ave and Techwood intersection" +
      "Begin on the corner closest to Bobby Dodd Stadium" +
      "Please proceed with caution of vehicles and other obstacles on the sidewalk.");
  }
}

// uses wavePlayer to generate sine wave
// low frequency indicating forceful, high frequency indicating light
public void toggleGaitPattern() {
  if (enableGaitPattern) {
    toggle.start(0);
    wavePlayer.start();
  } else {
    unToggle.start(0);
    wavePlayer.pause(true);
  }
  enableGaitPattern = !enableGaitPattern;
}

// reset all sonfications
public void resetAll() {
  unToggle.start(0);
  cadenceTick.pause(true);
  enableCadence = !enableCadence;
  heartRateBeep.pause(true);
  enableHeartRate = !enableHeartRate;
  gaitPatternIntensity.pause(true);
  enableGaitPattern = !enableGaitPattern;
  strideLengthSynth.pause(true);
  enableStrideLength = !enableStrideLength;
}

public void setFilter() {
  if (toggleLowPassFilter() == true) {
    masterGainGlide.setValue(filterGlide.getValue() * 1000);
  }
}

public boolean toggleLowPassFilter() {
  if (toggleFilter == true) {
    toggle.start(0);
    toggleFilter = !toggleFilter;
    return toggleFilter;
  } else {
    unToggle.start(0);
    toggleFilter = !toggleFilter;
    return toggleFilter;
  }
}

// gradualy change cadence value using linear interpolation
public void heartRateCheck() {
  // Heart Rate too high -> Lower Target Cadence until heart rate reaches healthy level
  if (heartRateKnob.getValue() > 185) {
    heartRateKnob.setColorForeground(color(140, 46, 71));
    heartRateKnob.setColorActive(color(217, 13, 67));
    heartRateStatus = "Too High";
  } else {
    heartRateKnob.setColorForeground(color(214, 150, 198));
    heartRateKnob.setColorActive(color(176, 137, 166));
    heartRateStatus = "Stable";
  }
  if (heartRateKnob.getValue() > 185) {
    float value = lerp((float)cadenceKnob.getValue(), 120.0, 0.0005);
    cadenceKnob.setValue(value);
  }
}

public void ConstructUI() {
  p5.addButton("toggleCadence")
    .setSize(150, 30)
    .setLabel("Set Pace")
    .setPosition(30, 40)
    .setColorForeground(color(113, 182, 201))
    .setColorBackground(color(81, 105, 184))
    .setColorActive(color(113, 182, 201))
    .activateBy((ControlP5.RELEASE));

  p5.addButton("toggleHeartRate")
    .setSize(150, 30)
    .setLabel("Target Heart Rate")
    .setPosition(30, 80)
    .setColorForeground(color(113, 182, 201))
    .setColorBackground(color(81, 105, 184))
    .setColorActive(color(113, 182, 201))
    .activateBy((ControlP5.RELEASE));

  p5.addButton("toggleStrideLength")
    .setSize(150, 30)
    .setLabel("Play Music")
    .setPosition(30, 120)
    .setColorForeground(color(113, 182, 201))
    .setColorBackground(color(81, 105, 184))
    .setColorActive(color(113, 182, 201))
    .activateBy((ControlP5.RELEASE));

  p5.addButton("toggleGaitPattern")
    .setSize(150, 30)
    .setLabel("Toggle Gait Pattern")
    .setPosition(30, 160)
    .setColorForeground(color(113, 182, 201))
    .setColorBackground(color(81, 105, 184))
    .setColorActive(color(113, 182, 201))
    .activateBy((ControlP5.RELEASE));

  p5.addButton("toggleGPS")
    .setSize(150, 30)
    .setLabel("Enable GPS")
    .setPosition(30, 200)
    .setColorForeground(color(113, 182, 201))
    .setColorBackground(color(81, 105, 184))
    .setColorActive(color(113, 182, 201))
    .activateBy((ControlP5.RELEASE));

  p5.addButton("resetAll")
    .setLabel("Reset Sonifications")
    .setSize(150, 30)
    .setPosition(30, 240)
    .setColorForeground(color(113, 182, 201))
    .setColorBackground(color(81, 105, 184))
    .setColorActive(color(113, 182, 201))
    .activateBy((ControlP5.RELEASE));
    
  p5.addButton("toggleDemo")
    .setLabel("DEMO")
    .setSize(150, 15)
    .setPosition(width/2 + 20, 550)
    .setColorForeground(color(113, 182, 201))
    .setColorBackground(color(81, 105, 184))
    .setColorActive(color(113, 182, 201))
    .activateBy((ControlP5.RELEASE));
  

  p5.addButton("recommendNavigation")
    .setLabel("Suggest Route Guidance")
    .setSize(250, 20)
    .setPosition(75, 560)
    .setColorForeground(color(113, 182, 201))
    .setColorBackground(color(81, 105, 184))
    .setColorActive(color(113, 182, 201))
    .activateBy((ControlP5.RELEASE));

  p5.addSlider("MasterGainSlider")
    .setValue(20)
    .setSize(30, 230)
    .setLabel("Volume")
    .setPosition(200, 40)
    .setColorForeground(color(113, 182, 201))
    .setColorBackground(color(81, 105, 184))
    .setColorActive(color(113, 182, 201));

  gaitPatternSlider = p5.addSlider("GaitPatternSlider")
    .setValue(2500)
    .setSize(30, 230)
    .setRange(10, 20000)
    .setLabel("Gait Pattern Intensity")
    .setPosition(330, 40)
    .setColorForeground(color(113, 182, 201))
    .setColorBackground(color(81, 105, 184))
    .setColorActive(color(113, 182, 201));

  paceSlider = p5.addSlider("paceSlider")
    .setSize(30, 230)
    .setRange(200, 4000)
    .setValue(1500)
    .setLabel("Target Pace")
    .setPosition(265, 40)
    .setColorForeground(color(113, 182, 201))
    .setColorBackground(color(81, 105, 184))
    .setColorActive(color(113, 182, 201));

  // controls frequency of both cadence (SPM) and gait pattern intensity.
  cadenceKnob = p5.addKnob("SetTargetCadence")
    .setViewStyle(Knob.ARC)
    .setColorForeground(color(166, 182, 222))
    .setColorActive(color(118, 140, 196))
    .setColorBackground(color(35, 60, 122))
    .setNumberOfTickMarks(15)
    .setTickMarkLength(4)
    .snapToTickMarks(false)
    .setDragDirection(Slider.VERTICAL)
    .setPosition(415, 30)
    .setRadius(85)
    .setAngleRange(2*PI) // radians
    .setRange(120, 220)
    .setValue(140)
    .setLabel("Target Pace")
    .plugTo(this, "SetTargetCadence");

  // controls frequency of heart rate (BPM)
  heartRateKnob = p5.addKnob("SetTargetHeartRate")
    .setViewStyle(Knob.ARC)
    .setColorForeground(color(113, 182, 201))
    .setColorActive(color(0, 200, 150))
    .setColorBackground(color(35, 60, 122))
    .setNumberOfTickMarks(15)
    .setTickMarkLength(4)
    .setDragDirection(Slider.VERTICAL)
    .setPosition(614, 100)
    .setRadius(75)
    .setAngleRange(2*PI) // radians
    .setRange(60, 200)
    .setValue(100)
    .setLabel("Target Heart Rate");

  // replace with GPS
}

// UI Geometry and Function Calls
void draw() {
  
  frameRate(framerate);
  
  // function calls
  if (cadenceKnob.getValue() >= 150 && heartRateKnob.getValue() >= 150.0) {
    if (cadenceAlert) {
      ttsExamplePlayback("Remember to inhale deeply and exhale fully");
      // maybe play a breathing pattern using samplePlayer
      cadenceAlert = false;
    } else {
      // otherwise pause the breathing pattern, and/or suggest a slower one
    }
  }
  heartRateCheck();
  if (heartRateKnob.getValue() >= 185) {
    if (heartRateAlert) {
      ttsExamplePlayback("Heart rate too high, lowering target cadence");
      heartRateAlert = false;
    }
    if (heartRateAlert == false && heartRateKnob.getValue() < 160) {
      ttsExamplePlayback("Heart rate now stable");
    }
  }
  setStrideLength();

  // UI Geometry/Data Visual
  background(color(20, 20, 20));

  fill(40, 40, 40);
  rect(10, 10, 780, 280);
  rect(10, height/2, 385, 290);
  //rect(width/2 + 120, 20, 250, 250);
  image(Navigation, 85, 320, 230, 230);


  fill(255);
  textSize(15);
  text("Check Body Measurements with Sonifications", 30, 30);
  text("Sensor Data", width/2 + 10, height/2 + 20);
  text("Current Pace (SPM) - " + (int)cadenceKnob.getValue(), width/2 + 20, height/2 + 60);
  text("Current Heart Rate (BPM) - " + (int)heartRateKnob.getValue(), width/2 + 20, height/2 + 90);
  text("Gait Pattern - ", width/2 + 20, height/2 + 120);
  text("Stride length (feet) - " + String.format("%.02f", StrideLengthValue), width/2 + 20, height/2 + 150);
  text("Velocity (miles/hour) - " + String.format("%.02f", velocity), width/2 + 20, height/2 + 180);
  text("Pace (minutes/mile) - " + String.format("%.02f", paceSlider.getValue()/60.0f), width/2 + 20, height/2 + 210);

  // UI extras
  if (heartRateKnob.getValue() > 185) {
    fill(255, 0, 0);
    text(heartRateStatus, width/2 + 215, height/2 + 90);
  } else {
    fill(0, 255, 0);
    text(heartRateStatus, width/2 + 215, height/2 + 90);
  }

  gaitPatternI = getGaitPatternIntensity();
  if (gaitPatternI == "Normal") {
    fill(0, 120, 255);
    text(gaitPatternI, width/2 + 165, height/2 + 120);
  } else if (gaitPatternI == "Shuffling") {
    fill(0, 255, 0);
    text(gaitPatternI, width/2 + 165, height/2 + 120);
  } else if (gaitPatternI == "Freezing") {
    fill(255, 0, 0);
    text(gaitPatternI, width/2 + 165, height/2 + 120);
  } else {
    fill(255);
    text(gaitPatternI, width/2 + 165, height/2 + 120);
  }
  
    
  if (toggleDemoCondition) { 
    if (frameCount < cadenceData.size()) {
      JSONObject cadenceObject = cadenceData.getJSONObject(frameCount);
      if (cadenceObject != null && cadenceObject.hasKey("cadence")) {
        float cadence = cadenceObject.getFloat("cadence");
        cadenceKnob.setValue(cadence);
      }
    } if (frameCount < heartRateData.size()) {
      JSONObject hrObject = heartRateData.getJSONObject(frameCount);
      if (hrObject != null && hrObject.hasKey("heart_rate")) {
        float hr = hrObject.getFloat("heart_rate");
        heartRateKnob.setValue(hr);
      }
    }
    frameCount++;
  }
}

public void toggleDemo() {
  if (!toggleDemoCondition) {
    toggle.start(0);
    ttsExamplePlayback("Loading J-SON Data");
    toggleDemoCondition = !toggleDemoCondition;
    framerate = 1;
    frameCount = 0;
  } else {
    unToggle.start(0);
    ttsExamplePlayback("Interactive Mode");
    toggleDemoCondition = !toggleDemoCondition;
    framerate = 1000;
    frameCount = 0;
  }
  
}

public Bead endListener() {
  Bead endListener = new Bead() {
    public void messageReceived(Bead message) {
      SamplePlayer sp = (SamplePlayer) message;
      cadenceGlide.setValue(0);
      heartRateGlide.setValue(0);
      sp.pause(true);
    }
  };
  return endListener;
}

// Text to Speech Requirement
void ttsExamplePlayback(String inputSpeech) {
  //create TTS file and play it back immediately
  //the SamplePlayer will remove itself when it is finished in this case
  String ttsFilePath = ttsMaker.createTTSWavFile(inputSpeech);
  println("File created at " + ttsFilePath);

  //createTTSWavFile makes a new WAV file of name ttsX.wav, where X is a unique integer
  //it returns the path relative to the sketch's data directory to the wav file

  //see helper_functions.pde for actual loading of the WAV file into a SamplePlayer
  SamplePlayer sp = getSamplePlayer(ttsFilePath, true);
  //true means it will delete itself when it is finished playing
  //you may or may not want this behavior!

  ac.out.addInput(sp);
  sp.setToLoopStart();
  sp.start();
  println("TTS: " + inputSpeech);
}
