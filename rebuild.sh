#!/bin/bash
cd frontend/my-app
npm run build
cd ../..
docker-compose restart backend