
#include <thrust\host_vector.h>
#include <thrust\device_vector.h>
#include <npp.h>
#include <stdio.h>
#include <windows.h>

struct muldiv_functor
{
	unsigned int a;

	muldiv_functor(unsigned int nConstant, unsigned int nNormalizer) {
		a = round(nConstant / nNormalizer); 
	}

	__host__ __device__
		Npp8u operator()(const Npp8u& x) const
	{
		return a*x ;
	}
};

double PCFreq = 0.0;
__int64 CounterStart = 0;

void StartCounter()
{
	LARGE_INTEGER li;
	if (!QueryPerformanceFrequency(&li))
		std::cout << "QueryPerformanceFrequency failed!\n";

	PCFreq = double(li.QuadPart) / 1000.0;

	QueryPerformanceCounter(&li);
	CounterStart = li.QuadPart;
}
double GetCounter()
{
	LARGE_INTEGER li;
	QueryPerformanceCounter(&li);
	return double(li.QuadPart - CounterStart) / PCFreq;
}

// Function Protypes.
thrust::host_vector<Npp8u>
LoadPGM(char * sFileName, int & nWidth, int & nHeight, int & nMaxGray);

void
WritePGM(char * sFileName, thrust::host_vector<Npp8u> pDst_Host, int nWidth, int nHeight, int nMaxGray);

int main()
{
	thrust::host_vector<Npp8u> pSrc_Host;
	int   nWidth, nHeight, nMaxGray;
	unsigned int nNormalizer;
	std::cout << "THRUST VERSION" << std::endl;

	// Load image to the host.
	std::cout << "Load PGM file." << std::endl;
	pSrc_Host = LoadPGM("lena_before.pgm", nWidth, nHeight, nMaxGray);
	StartCounter();
	thrust::device_vector<Npp8u> pDst_Dev = pSrc_Host;
	std::cout << "Host to Device Memory Copy Duration : " <<GetCounter() << " seconds." << std::endl;
	
	//Finding Minimum
	StartCounter();
	int nMin = thrust::reduce(pDst_Dev.begin(), pDst_Dev.end(),257, thrust::minimum<int>());
	std::cout << "Finding Minimum Execution Time : " << GetCounter() << " seconds." << std::endl;

	//Finding Maximum
	StartCounter();
	int nMax = thrust::reduce(pDst_Dev.begin(), pDst_Dev.end(), 0, thrust::maximum<int>());
	std::cout << "Finding Maximum Execution Time : " << GetCounter() << " seconds." << std::endl;
	printf("The minimum value is %d, and the maximum value is %d.\n", nMin, nMax);

	std::cout << "Subracting the minimum value." << std::endl;
	StartCounter();
	thrust::for_each(pDst_Dev.begin(), pDst_Dev.end(), thrust::placeholders::_1 -= nMin);
	std::cout << "Subraction Execution Time : " << GetCounter() << " seconds." << std::endl;
	/*for (thrust::device_vector<Npp8u>::iterator  i = pDst_Dev.begin(); i!= pDst_Dev.end(); i++)
	{
		*i -= nMin;
	}*/
	std::cout << "Subraction finished." << std::endl;

	// Compute the optimal nConstant and nScaleFactor for integer operation see GTC 2013 Lab NPP.pptx for explanation
	// I will prefer integer arithmetic, Instead of using 255.0f / (nMax_Host - nMin_Host) directly
	int nScaleFactor = 0;
	int nPower = 1;
	while (nPower * 255.0f / (nMax - nMin) < 255.0f)
	{
		nScaleFactor++;
		nPower *= 2;
	}
	unsigned int nConstant = 255.0f / (nMax - nMin) * (nPower / 2);
	
	nNormalizer = pow(2, (nScaleFactor - 1));
	
	std::cout << "Multiplying by the constant, and dividing by normalizer." << std::endl;
	StartCounter();
	thrust::transform(pDst_Dev.begin(), pDst_Dev.end(), pDst_Dev.begin(), muldiv_functor(nConstant, nNormalizer));
	std::cout << "Multiplication Execution Time : " << GetCounter() << " seconds." << std::endl;
	/*for (thrust::device_vector<Npp8u>::iterator i = pDst_Dev.begin(); i != pDst_Dev.end(); i++)
	{
		*i = static_cast<Npp8u>(*i * (nConstant/nNormalizer));
	}*/
	std::cout << "Multiplication, and division finished." << std::endl;
	// Output the result image.
	StartCounter();
	thrust::host_vector<Npp8u> pDst_Host=pDst_Dev;
	std::cout << "Device to Host Copy Duration : " << GetCounter() << " seconds." << std::endl;

	std::cout << "Output the PGM file." << std::endl;
	WritePGM("lena_after_GPU_Thrust.pgm", pDst_Host, nWidth, nHeight, nMaxGray);
	getchar();
    return 0;
}

// Load PGM file.
thrust::host_vector<Npp8u>
LoadPGM(char * sFileName, int & nWidth, int & nHeight, int & nMaxGray)
{
	char aLine[256];
	FILE * fInput = fopen(sFileName, "r");
	if (fInput == 0)
	{
		perror("Cannot open file to read");
		exit(EXIT_FAILURE);
	}
	// First line: version
	fgets(aLine, 256, fInput);
	std::cout << "\tVersion: " << aLine;
	// Second line: comment
	fgets(aLine, 256, fInput);
	std::cout << "\tComment: " << aLine;
	fseek(fInput, -1, SEEK_CUR);
	// Third line: size
	fscanf(fInput, "%d", &nWidth);
	std::cout << "\tWidth: " << nWidth;
	fscanf(fInput, "%d", &nHeight);
	std::cout << " Height: " << nHeight << std::endl;
	// Fourth line: max value
	fscanf(fInput, "%d", &nMaxGray);
	std::cout << "\tMax value: " << nMaxGray << std::endl;
	while (getc(fInput) != '\n');
	// Following lines: data
	thrust::host_vector<Npp8u> pSrc_Host(0);
	for (int i = 0; i < nHeight; ++i)
		for (int j = 0; j < nWidth; ++j)
		{
			pSrc_Host.push_back(fgetc(fInput));
		}
	fclose(fInput);
	return pSrc_Host;
}

// Write PGM image.
void
WritePGM(char * sFileName, thrust::host_vector<Npp8u> pDst_Host, int nWidth, int nHeight, int nMaxGray)
{
	FILE * fOutput = fopen(sFileName, "wb");
	if (fOutput == 0)
	{
		perror("Cannot open file to read");
		exit(EXIT_FAILURE);
	}
	char * aComment = "# Created by NPP";
	fprintf(fOutput, "P5\n%s\n%d %d\n%d\n", aComment, nWidth, nHeight, nMaxGray);
	for (thrust::host_vector<Npp8u>::iterator i = pDst_Host.begin(); i != pDst_Host.end(); i++)
	{
		fputc(*i, fOutput);
	}
			
	fclose(fOutput);
}