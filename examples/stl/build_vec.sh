clang++ -c vec/v.cpp -o build/v.o
d++ --parse-as-cpp --c++-std-lib --keep-d-files -ofbin/vec -Ivec/ vec/app.dpp build/v.o
