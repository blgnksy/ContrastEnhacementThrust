
#include <thrust\host_vector.h>
#include <thrust\device_vector.h>
#include <npp.h>
#include <stdio.h>


//https://github.com/thrust/thrust/wiki/Quick-Start-Guide
// Function Protypes.
thrust::host_vector<Npp8u>
LoadPGM(char * sFileName, int & nWidth, int & nHeight, int & nMaxGray);

void
WritePGM(char * sFileName, Npp8u * pDst_Host, int nWidth, int nHeight, int nMaxGray);

int main()
{
	thrust::host_vector<Npp8u> pSrc_Host;
	int   nWidth, nHeight, nMaxGray, nNormalizer;

	std::cout << "THRUST VERSION" << std::endl;

	// Load image to the host.
	std::cout << "Load PGM file." << std::endl;
	pSrc_Host = LoadPGM("lena_before.pgm", nWidth, nHeight, nMaxGray);
	//pDst_Host = new Npp8u[nWidth * nHeight];
	
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
	thrust::host_vector<Npp8u> pSrc_Host(nWidth * nHeight);
	for (int i = 0; i < nHeight; ++i)
		for (int j = 0; j < nWidth; ++j)
		{
			pSrc_Host.push_back(fgetc(fInput));
			if (i < 5 && j < 5)
			{
				std::cout << fgetc(fInput) << std::endl;
			}
		}

	for (thrust::host_vector<Npp8u>::iterator i = pSrc_Host.begin(); i != pSrc_Host.begin()+25 ; i++)
	{
		std::cout << "pSrc_Host[" << &i << "] = " << *i << std::endl;
	}
	fclose(fInput);
	getchar();
	return pSrc_Host;
}

// Write PGM image.
void
WritePGM(char * sFileName, Npp8u * pDst_Host, int nWidth, int nHeight, int nMaxGray)
{
	FILE * fOutput = fopen(sFileName, "w+");
	if (fOutput == 0)
	{
		perror("Cannot open file to read");
		exit(EXIT_FAILURE);
	}
	char * aComment = "# Created by NPP";
	fprintf(fOutput, "P5\n%s\n%d %d\n%d\n", aComment, nWidth, nHeight, nMaxGray);
	for (int i = 0; i < nHeight; ++i)
		for (int j = 0; j < nWidth; ++j)
			fputc(pDst_Host[i*nWidth + j], fOutput);
	fclose(fOutput);
}