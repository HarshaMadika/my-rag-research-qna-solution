#!/bin/bash

echo " Starting backend..."
uvicorn api:app --reload &

sleep 2

echo " Starting frontend..."
cd frontend
flutter run -d chrome
