clang++ -c variant/variant.cpp -o build/variant.o
d++ --parse-as-cpp --c++-std-lib --keep-d-files -ofbin/var -Ivariant/ variant/variantd.dpp build/variant.o
