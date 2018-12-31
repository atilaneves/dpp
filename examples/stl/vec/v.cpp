#include <vector>
#include <string>
#include <map>
#include "v.hpp"
#include "stdio.h"

using std::vector;
using std::string;
using std::map;
using std::pair;

double* getVectorDataDouble(void* bytes)
{
	auto size = getVectorSize<double>(bytes);
	return (double*) getVectorData<double>(bytes);
}


Problem problem(double* values, size_t numValues)
{
	Problem ret;
	for(ulong i=0;i<numValues;++i)
		ret.values.push_back(values[i]);
	return ret;
}

size_t getVectorFoo(struct Problem* problem)
{
	return problem->values.size();
}
