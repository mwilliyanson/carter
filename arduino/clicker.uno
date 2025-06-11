#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <WiFiClientSecure.h>
#include <Servo.h>

// WiFi credentials
const char* ssid = "111";
const char* password = "111";

// Global objects
Servo myservo;
WiFiClientSecure client;

unsigned long lastCurlMillis = 0;
const unsigned long curlInterval = 15000; // 10 seconds
int reconnectAttempts = 0;

void moveServoAction() {
  myservo.write(30);
  //Serial.println("Servo moved to 30");
  delay(500);
  myservo.write(90);
  //Serial.println("Servo moved to 90");
  Serial.println("Servo moved");
}

void checkStatusFromAPI() {
  //Serial.print("WiFi status: ");
  //Serial.println(WiFi.status());

  if (WiFi.status() != WL_CONNECTED && WiFi.status() != WL_IDLE_STATUS) {
    Serial.println("WiFi not connected, skipping API call");
    return;
  }

  Serial.print("Free heap before HTTP call: ");
  Serial.println(ESP.getFreeHeap());

  client.setInsecure();  // ONLY for development. Use certificate or fingerprint for production.

  HTTPClient http;
  if (!http.begin(client, "https://www.x.id/wolverine/get-status?key=POWER")) {
    Serial.println("http.begin() failed");
    return;
  }

  http.setTimeout(5000);  // Prevent hang if server is slow

  int httpCode = http.GET();
  //Serial.print("HTTP Response Code: ");
  //Serial.println(httpCode);

  if (httpCode > 0) {
    if (http.getSize() > 0) {
      String payload = http.getString();
      payload.trim();

      if (payload.length() == 0) {
        Serial.println("Payload kosong.");
        http.end();
        return;
      }

      //Serial.println("Payload: " + payload);

      if (payload == "ACTIVE") {
        Serial.println("Payload: " + payload);
        moveServoAction();
      } else {
        //Serial.println("Status bukan 'wakeup'");
      }
    } else {
      Serial.println("Empty or invalid content");
    }
  } else {
    Serial.printf("HTTP GET failed, error: %s\n", http.errorToString(httpCode).c_str());
  }

  http.end(); // Always clean up
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("Booting...");

  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected. IP address:");
  Serial.println(WiFi.localIP());

  myservo.attach(D1);  // Connect servo to D1 (GPIO5)
  myservo.write(90);   // Initial neutral position
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi lost. Reconnecting...");
    WiFi.begin(ssid, password);
    delay(1000);
    reconnectAttempts++;

    if (reconnectAttempts > 10) {
      Serial.println("Too many reconnect attempts. Restarting...");
      ESP.restart();
    }
    return;
  } else {
    reconnectAttempts = 0;
  }

  unsigned long currentMillis = millis();
  if (currentMillis - lastCurlMillis >= curlInterval) {
    lastCurlMillis = currentMillis;
    checkStatusFromAPI();
  }

  delay(10);  // Give time for WiFi and background tasks
}