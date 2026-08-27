#ifndef IMAGEFILES_H
#define IMAGEFILES_H


// wmimagedock
//  files.hpp
//
//  Copyright (c) 2018 Michael Heras
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111-1307,
//  USA.
//


#define PATH_MAX 4096

#include <boost/filesystem.hpp>
#include <boost/range/iterator_range.hpp>
#include <string>

class WMWindowDock;

struct options {
int i = 0;
int g = 0;
//to be compatable with vector.size() retrun data type
unsigned long int leftoff = 0;
char *path = NULL;
//holds file names
std::vector<std::string> dfile;
int single_file = 0;
int writeTofile = 0;
int FilesLoaded = 0;

};

size_t loadFiles(std::vector<std::string> &mylist , boost::filesystem::path p);
std::string getFileExt(const std::string& s);
std::string getFileExt(const std::string& s, int len);
size_t checkFileExt(std::string extension);
std::string get_random_file();
std::string transverseList();
void sortList();
bool compareNoCase (std::string first, std::string second);
int Load_single_Image();
void load_image_err();
std::string get_file_name(WMWindowDock d);
int load_image_err(std::string path, WMWindowDock d );
size_t getRany(int min, int max);
int loadFiles_FromList(std::vector<std::string> &mylist, std::string file);
void Print_FromFileList(std::vector<std::string> &aList);
void writeToFile(std::vector<std::string> &mylist, std::string file);
bool checkIfFile(std::string filePath);
bool checkIfDirectory(std::string filePath);
int64_t int_or_ch(char *data);

extern options opts;
#endif
