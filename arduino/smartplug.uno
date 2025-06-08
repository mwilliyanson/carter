#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <ArduinoOTA.h>

const char* ssid = "xxx";
const char* password = "xxx";

ESP8266WebServer server(80);

const int buttonPin = 0;  
const int relayPin = 12;   

bool relayState = false;
bool buttonPressed = false;  // NEW: track physical button press event
bool lastButtonState = HIGH;  

unsigned long lastDebounceTime = 0;
const unsigned long debounceDelay = 50;

void setup() {
  Serial.begin(115200);

  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected!");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());

  pinMode(buttonPin, INPUT_PULLUP);
  pinMode(relayPin, OUTPUT);
  digitalWrite(relayPin, relayState ? HIGH : LOW);

  ArduinoOTA.setHostname("sonoff-relay");
  ArduinoOTA.begin();

  server.on("/", HTTP_GET, handleRoot);
  server.on("/toggle", HTTP_GET, handleToggle);
  server.on("/state", HTTP_GET, handleState);

  server.begin();
  Serial.println("HTTP server started");
}

void loop() {
  ArduinoOTA.handle();
  server.handleClient();

  int reading = digitalRead(buttonPin);

  if (reading != lastButtonState) {
    lastDebounceTime = millis();
  }
  
  if ((millis() - lastDebounceTime) > debounceDelay) {
    if (reading == LOW && lastButtonState == HIGH) {
      // Button pressed
      relayState = true;         // Force relay ON
      digitalWrite(relayPin, HIGH);
      buttonPressed = true;      // Flag for homepage
      Serial.println("Physical button pressed: Horray! Relay ON");
    }
  }
  lastButtonState = reading;
}

// Serve main page with toggle and "Horray" if button pressed
void handleRoot() {
  String html = "<!DOCTYPE html><html><head><title>Sonoff Relay Control</title>";
  html += "<script>";
  html += "function toggleRelay() {";
  html += "  fetch('/toggle').then(() => updateState());";
  html += "}";
  html += "function updateState() {";
  html += "  fetch('/state').then(response => response.json()).then(data => {";
  html += "    document.getElementById('relayState').innerText = data.relay ? 'ON' : 'OFF';";
  html += "    document.getElementById('toggleBtn').innerText = data.relay ? 'Turn OFF' : 'Turn ON';";
  html += "  });";
  html += "}";
  html += "setInterval(updateState, 1000);";
  html += "</script></head><body>";
  html += "<h1>Sonoff Relay Control</h1>";

  if (buttonPressed) {
    html += "<p><strong>Horray! Button pressed.</strong></p>";
    buttonPressed = false; // Clear after showing once
  }

  html += "<p>Relay state: <span id='relayState'>Unknown</span></p>";
  html += "<button id='toggleBtn' onclick='toggleRelay()'>Toggle</button>";
  html += "</body></html>";

  server.send(200, "text/html", html);
}

// Toggle relay via web
void handleToggle() {
  relayState = !relayState;
  digitalWrite(relayPin, relayState ? HIGH : LOW);
  Serial.printf("Web toggled relay: %s\n", relayState ? "ON" : "OFF");
  server.send(200, "text/plain", "OK");
}

// Send relay state as JSON
void handleState() {
  String json = "{\"relay\":" + String(relayState ? "true" : "false") + "}";
  server.send(200, "application/json", json);
}
