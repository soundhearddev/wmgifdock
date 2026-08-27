#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <string>
#include <cstring>
#include <algorithm>
#include <random>
#include <dirent.h>
#include <unistd.h>
#include <stdarg.h>
#include <ctime>
#include <cstdlib>
#include <sys/types.h>
#include <sys/stat.h> //type dir/file
#include <stdlib.h> //exit
#include <Imlib2.h> //Imlib_Load_Error

#include "wmgifdock.hpp"
#include "imagefiles.hpp"

options opts;

using namespace boost::filesystem;

namespace filesys = boost::filesystem;

struct recursive_directory_range
{
    typedef recursive_directory_iterator iterator;
    recursive_directory_range(path p) : p_(p) {}

    iterator begin() { return recursive_directory_iterator(p_); }
    iterator end() { return recursive_directory_iterator(); }

    path p_;
};
size_t loadFiles(std::vector<std::string> &mylist , boost::filesystem::path p)
{

  for (auto it : recursive_directory_range(p))
  {
      //convert char to string
      std::stringstream newStringPath;
      newStringPath << it;
      std::string myStringPath = newStringPath.str();

    if (  checkFileExt(getFileExt(myStringPath)) == 1 )
    {
         // Remove all double-quote characters
        myStringPath.erase(
        remove( myStringPath.begin(), myStringPath.end(), '\"' ),
        myStringPath.end() );

        mylist.push_back( myStringPath );
    }
 }
 return 0;
 }

std::string getFileExt(const std::string& s)
{
    size_t i = s.rfind('.', s.length());
    try
    {
        if (i != std::string::npos)
        {
            std::string lext = (s.substr(i+1, s.length() - i));
            return (lext.erase(lext.size() - 1));
        }
    }
    catch(...)
    {
        std::cout<<"Exception Caught!"<<std::endl;
        std::cout<<s<<std::endl;
    }
   return("");
}
std::string getFileExt(const std::string& s, int len)
{
    size_t i = s.rfind('.', s.length());
    try
    {
        if (i != std::string::npos)
        {
            std::string lext = (s.substr(i+1, s.length() - i));
            return (lext.erase(lext.size() - len));
        }
    }
    catch (...)
    {
        std::cout<<"Exception Caught!!"<<std::endl;
        std::cout<<s<<std::endl;
    }
   return("");
}
size_t checkFileExt(std::string extension)
{
    std::vector <std::string> extensions = {"jpg", "JPG", "png", "jpeg", "gif" , "xpm"};

    for ( unsigned int i = 0; i < extensions.size(); i++)
        if (extension == extensions[i]){
            return 1;
        }
    return 0;
}




// Comparison; not case sensitive.
bool compareNoCase (std::string first, std::string second)
{
  unsigned long int  i = 0;
  while ((i < first.length()) && (i < second.length()))
  {
    if (tolower (first[i]) < tolower (second[i])) return true;
    else if (tolower (first[i]) > tolower (second[i])) return false;
    i++;
  }

  if (first.length() < second.length()) return true;
  else return false;
}


size_t getRany(int min, int max)
{
    std::random_device seed;
    std::mt19937 gen(seed());
    std::uniform_int_distribution<int> dist(min, max);
    return ( dist(gen) );
}
int loadFiles_FromList(std::vector<std::string> &mylist, std::string file)
{

    std::ifstream myfile(file.c_str());
    if (myfile.is_open())
    {
        std::string line;

        while ( getline (myfile,line) )
        {
             if (  checkFileExt(getFileExt(line, 0) ) == 1 )
                mylist.push_back( line );
        }
        myfile.close();
        return 0;
    }
    else
        std::cout<<" Not able to open file"<<"\n";
    return 1;
}

void Print_FromFileList(std::vector<std::string> &aList)
{
      for ( auto i: aList )
    {
        std::cout << i <<"\n";
    }
}

void writeToFile(std::vector<std::string> &mylist, std::string file)
{
    std::ofstream theFile (file);
    if (theFile.is_open())
    {
        for ( auto i : mylist)
        {
            theFile << i << "\n";
        }
        theFile.close();
    }
    else
        std::cout<<"Unable to open output file "<<file<<std::endl;
}

bool checkIfFile(std::string filePath)
{
    try {
        // Create a Path object from given path string
        filesys::path pathObj(filePath);
        // Check if path exists and is of a regular file
        if (filesys::exists(pathObj) && filesys::is_regular_file(pathObj))
            return true;
    }
    catch (filesys::filesystem_error & e)
    {
        std::cerr << e.what() << std::endl;
    }
    return false;
}

bool checkIfDirectory(std::string filePath)
{
    try {
        // Create a Path object from given path string
        filesys::path pathObj(filePath);
        // Check if path exists and is of a directory file
        if (filesys::exists(pathObj) && filesys::is_directory(pathObj))
            return true;
    }
    catch (filesys::filesystem_error & e)
    {
        std::cerr << e.what() << std::endl;
    }
    return false;
}
int64_t int_or_ch(char *data)
{
    int len = 0, i;
    char *endptr;

    len = strlen(data);

    for ( i = 0; i < len ; i++)
    {// if not a digit return error code -1
        if ( isdigit(data[i]) == 0)
            return 7;
     }
     return strtol(data, &endptr, 10);
}
int load_image_err(std::string path, WMWindowDock d )
{
    Imlib_Load_Error err;
    Imlib_Image tempImage;
    const char *fpath = path.c_str();

     //check function to see if it is working.
    tempImage = imlib_load_image_with_error_return(fpath, &err);
    d.setBuffer( tempImage );

    if (err)
    {
        std::cout<<"Bad Image: "<<fpath<<std::endl;

        return 1;
    }


         return 0;


}
