#include "variant.hpp"
#include "boost/variant.hpp"
#include <string>


void dummy_(void* v)
{
	double d =1.0;
	int i = 1;
	std::string s = "hello";
	variantGet<double>(v);
	variantGet<int>(v);
	variantGet<std::string>(v);
	variantSet<double>(v,(void*)&d);
	variantSet<int>(v,(void*)&i);
	variantSet<std::string>(v,(void*)&s);
}
