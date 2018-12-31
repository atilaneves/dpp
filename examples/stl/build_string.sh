clang++ -c -o build/stlstringcpp.o str/stlstringcpp.cpp
d++ --include-path str/ str/stlstring.dpp -ofbin/str build/stlstringcpp.o -L-lstdc++ -Istr
