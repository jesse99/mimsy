#!/usr/bin/env bash
# This is used to generate C style collections for various vector types that need to be efficient.
# I'm sure there are similar generators available but I couldn't find much when googling (although
# I mostly googled for macro versions). The options I know about are:
# 1) NSArray - Element types must be heap allocated which can be very expensive.
# 2) utarray - Likely more efficient than NSArray, but still requires heap allocated elements.

./Mimsy/create-vector.py --element=int --struct=TestVector --size=NSUInteger > ./MimsyTests/TestVector.h
./Mimsy/create-vector.py --element=NSUInteger --struct=UIntVector --size=NSUInteger > ./Mimsy/UIntVector.h
./Mimsy/create-vector.py --element='struct StyleRun' --struct=StyleRunVector --size=NSUInteger --headers='StyleRun.h' > ./Mimsy/StyleRunVector.h
