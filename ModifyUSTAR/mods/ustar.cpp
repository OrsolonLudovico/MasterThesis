#include <iostream>
#include <fstream>
#include <getopt.h>
#include <chrono>
#include <cstdint>
#include <filesystem>

#include "DBG.h"
#include "SPSS.h"
#include "Encoder.h"
#include "consts.h"
#include "commons.h"

using namespace std;
using namespace std::chrono;
namespace fs = std::filesystem;

struct params_t{
    string input_file_name{};
    string fasta_file_name{};
    string counts_file_name{};

    int kmer_size = 31;

    bool debug = false;
    bool batch_mode = false;  // Process input file as a list of files
    bool skip_counts = false; // Do not write counts file

    encoding_t encoding = encoding_t::PLAIN;
    seeding_method_t seeding_method = seeding_method_t::FIRST;
    extending_method_t extending_method = extending_method_t::FIRST;
};


void print_help(const params_t &params){
    cout << "Find a Spectrum Preserving String Set (aka simplitigs) for the input file.\n";
    cout << "Compute the kmer counts vector.\n\n";

    cout << "Usage: ./USTAR -i <input_file_name>\n\n";

    cout << "Basic options:\n\n";

    cout << "   -k  kmer size, must be the same of BCALM2 [" << params.kmer_size << "]\n\n";

    cout << "   -c  counts file name [" << params.counts_file_name << "]\n\n";

    cout << "   -o  fasta file name [" << params.fasta_file_name << "]\n\n";

    cout << "   -v  print version and author\n\n";

    cout << "   -h  print this help\n\n" << endl;

    cout << "Advanced options:\n\n";

    cout << "   -s  seeding method [" << inv_map<seeding_method_t>(seeding_method_names, params.seeding_method) << "]\n";
    cout << "       f               choose the first seed available\n";
    cout << "       r               choose a random seed\n";
    cout << "       -ma             choose the seed with lower median abundance\n";
    cout << "       +aa             choose the seed with higher average abundance\n";
    cout << "       -aa             choose the seed with lower average abundance\n";
    cout << "       =a              choose the seed with most similar abundance to the last selected node\n";
    cout << "       -l              choose the seed with smaller length\n";
    cout << "       +l              choose the seed with bigger length\n";
    cout << "       -c              choose the seed with less arcs\n";
    cout << "       +c              choose the seed with more arcs\n";
    cout << "\n";

    cout << "   -x  extending method [" << inv_map<extending_method_t>(extending_method_names, params.extending_method) << "]\n";
    cout << "       f               choose the first successor available\n";
    cout << "       r               choose a random successor\n";
    cout << "       =a              choose the successor with most similar abundance to the last selected node\n";
    cout << "       =ma             choose the successor with most similar median abundance to the last selected node\n";
    cout << "       -ma             choose the successor with lower abundance to the last selected node\n";
    cout << "       -l              choose the successor with smaller length\n";
    cout << "       +l              choose the successor with bigger length\n";
    cout << "       -c              choose the successor with less arcs\n";
    cout << "       +c              choose the successor with more arcs\n";
    cout << "\n";

    cout << "   -e  encoding [" << inv_map<encoding_t>(encoding_names, params.encoding)<< "]\n";
    cout << "       plain           do not use any encoding\n";
    cout << "       rle             use special Run Length Encoding\n";
    cout << "       avg_rle         sort simplitigs by average counts and use RLE\n";
    cout << "       flip_rle        make contiguous runs by flipping simplitigs if necessary and use RLE\n";
    cout << "       avg_flip_rle    make contiguous runs by sorting by average, flipping simplitigs if necessary and use RLE\n";
    cout << "\n";

    cout << "   -d  debug [" << (params.debug?"true":"false") << "]\n\n";

    cout << "   -b  batch mode: process input file as a list of files (one per line) [" << (params.batch_mode?"true":"false") << "]\n";
    cout << "       In batch mode, -o specifies output directory prefix\n";
    cout << "       If input file ends with .unitigs.fa, it's treated as single file, otherwise as file list\n\n";

    cout << "   -n  skip writing counts file [" << (params.skip_counts?"true":"false") << "]\n\n";
}

void print_params(const params_t &params){
    cout << "Params:\n";
    cout << "   input file:             " << params.input_file_name << "\n";
    cout << "   kmer size:              " << params.kmer_size << "\n";
    cout << "   fasta file name:        " << params.fasta_file_name << "\n";
    cout << "   counts file name:       " << params.counts_file_name << "\n";
    cout << "   seeding method:         " << inv_map<seeding_method_t>(seeding_method_names, params.seeding_method) << "\n";
    cout << "   extending method:       " << inv_map<extending_method_t>(extending_method_names, params.extending_method) << "\n";
    cout << "   encoding:               " << inv_map<encoding_t>(encoding_names, params.encoding) << "\n";
    cout << "   debug:                  " << (params.debug?"true":"false") << "\n";
    cout << "   batch mode:             " << (params.batch_mode?"true":"false") << "\n";
    cout << "   skip counts:            " << (params.skip_counts?"true":"false") << "\n";
    cout << endl;
}

void parse_cli(int argc, char **argv, params_t &params){
    bool got_input = false;
    bool new_counts_name = false;
    bool new_fasta_name = false;
    int c;
    while((c = getopt(argc, argv, "i:k:vo:dhe:s:x:c:bn")) != -1){
        switch(c){
            case 'i':
                params.input_file_name = string(optarg);
                got_input = true;
                break;
            case 'o':
                params.fasta_file_name = string(optarg);
                new_fasta_name = true;
                break;
            case 'c':
                params.counts_file_name = string(optarg);
                new_counts_name = true;
                break;
            case 'k':
                params.kmer_size = atoi(optarg);
                if(params.kmer_size <= 0) {
                    cerr << "parse_cli(): Need a positive kmer size!" << endl;
                    exit(EXIT_FAILURE);
                }
                if(params.kmer_size % 2 == 0){
                    cerr << "parse_cli(): You should use an odd kmer size in order to avoid auto-loops in the DBG!" << endl;
                    exit(EXIT_SUCCESS);
                }
                break;
            case 'v':
                cout << "Version: " << VERSION << "\n";
                cout << "Author: Enrico Rossignolo <enricorrx at gmail dot com>" << endl;
                exit(EXIT_SUCCESS);
            case 'd':
                params.debug = true;
                break;
            case 'b':
                params.batch_mode = true;
                break;
            case 'n':
                params.skip_counts = true;
                break;
            case 'e': // encoding
                // is a valid encoding?
                if(encoding_names.find(optarg) == encoding_names.end()){
                    cerr << "parse_cli(): " << optarg << " is not a valid encoding" <<endl;
                    exit(EXIT_FAILURE);
                }
                params.encoding = encoding_names.at(optarg);
                break;
            case 's': // seed method
                if(seeding_method_names.find(optarg) == seeding_method_names.end()){
                    cerr << "parse_cli(): " << optarg << " is not a valid seed method" <<endl;
                    exit(EXIT_FAILURE);
                }
                params.seeding_method = seeding_method_names.at(optarg);
                break;
            case 'x': // extension method
                if(extending_method_names.find(optarg) == extending_method_names.end()){
                    cerr << "parse_cli(): " << optarg << " is not a valid extension method" <<endl;
                    exit(EXIT_FAILURE);
                }
                params.extending_method = extending_method_names.at(optarg);
                break;
            case 'h':
                print_help(params);
                exit(EXIT_SUCCESS);
            case '?':
                cerr << "parse_cli(): missing argument or invalid option\n\n";
                print_help(params);
                exit(EXIT_FAILURE);
            default: // should never go here
                cerr << "parse_cli(): unknown option in optstring '" << c << "'\n\n";
                print_help(params);
                exit(EXIT_FAILURE);
        }
    }

    // check for input file
    if(!got_input){
        print_help(params);
        exit(EXIT_FAILURE);
    }

    // Auto-detect batch mode: if input file does NOT end with .unitigs.fa, treat it as a file list
    if(!params.batch_mode && params.input_file_name.rfind(".unitigs.fa") == string::npos) {
        params.batch_mode = true;
        cout << "Auto-detected batch mode: input file does not end with .unitigs.fa\n";
    }

    // --- derive names ---
    // input = "../experiments/SRR001665_1.unitigs.fa"
    // get a base name removing BCALM extension ".unitigs.fa"
    auto ext_pos = params.input_file_name.rfind(".unitigs.fa");
    auto slash_pos = params.input_file_name.rfind('/');
    auto name_pos = (slash_pos == string::npos) ? 0 : slash_pos + 1; // if file is in PWD start from 0
    auto base_name = params.input_file_name.substr(name_pos, ext_pos - name_pos);

    if(!new_fasta_name && !params.batch_mode)
        params.fasta_file_name = base_name + ".ustar.fa";
    if(!new_counts_name && !params.batch_mode)
        params.counts_file_name = base_name + ".ustar" + encoding_suffixes.at(params.encoding) + ".counts";
}

// Process a single input file
void process_single_file(const string &input_file, const params_t &params, const string &output_prefix = "", 
                        const string &custom_fasta = "", const string &custom_counts = "") {
    cout << "\n=== Processing file: " << input_file << " ===\n";
    
    string fasta_output, counts_output;

    // If custom names are provided, use them directly
    if (!custom_fasta.empty()) {
        fasta_output = custom_fasta;
        counts_output = custom_counts.empty() ? custom_fasta + ".counts" : custom_counts;
    } else {
        // Derive output file names from input file
        auto ext_pos = input_file.rfind(".unitigs.fa");
        auto slash_pos = input_file.rfind('/');
        auto name_pos = (slash_pos == string::npos) ? 0 : slash_pos + 1;
        auto base_name = input_file.substr(name_pos, ext_pos - name_pos);
        
        if (!output_prefix.empty()) {
            // Use output prefix directory
            fasta_output = output_prefix + base_name + ".ustar.fa";
            counts_output = output_prefix + base_name + ".ustar" + encoding_suffixes.at(params.encoding) + ".counts";
        } else {
            // Use same directory as input file
            string input_dir = (slash_pos == string::npos) ? "" : input_file.substr(0, slash_pos + 1);
            fasta_output = input_dir + base_name + ".ustar.fa";
            counts_output = input_dir + base_name + ".ustar" + encoding_suffixes.at(params.encoding) + ".counts";
        }
    }

    // Before heavy processing, verify we can create the output files (or directory)
    try {
        // Ensure output directory exists for fasta
        auto fasta_parent = fs::path(fasta_output).parent_path();
        if(!fasta_parent.empty()) fs::create_directories(fasta_parent);

        // Try opening files (counts may be skipped)
        ofstream fasta_test(fasta_output);
        if(!fasta_test.good()){
            cerr << "Error: cannot write fasta output: " << fasta_output << "\n";
            return;
        }
        fasta_test.close();

        if(!params.skip_counts){
            auto counts_parent = fs::path(counts_output).parent_path();
            if(!counts_parent.empty()) fs::create_directories(counts_parent);
            ofstream counts_test(counts_output);
            if(!counts_test.good()){
                cerr << "Error: cannot write counts output: " << counts_output << "\n";
                return;
            }
            counts_test.close();
        }
    } catch(const std::exception &e){
        cerr << "Filesystem error while preparing outputs: " << e.what() << "\n";
        return;
    }
    
    // Make a dBG
    cout << "Reading the input file..." << endl;
    auto start_time = steady_clock::now();
    DBG dbg(input_file, params.kmer_size, params.debug);
    auto stop_time = steady_clock::now();
    cout << "Reading time: " << duration_cast<seconds>(stop_time - start_time).count() << " s\n";
    dbg.print_stat();

    // Verify input
    if(params.debug) {
        if(!dbg.verify_input()){
            cerr << "Bad input file: " << input_file << endl;
            return;
        }
    }

    // Choose SPSS sorter
    Sorter sorter(params.seeding_method, params.extending_method, params.debug);
    // Make an SPSS
    SPSS spss(&dbg, &sorter, params.debug);

    cout << "Computing a path cover..." << endl;
    start_time = steady_clock::now();
    spss.compute_path_cover();
    stop_time = steady_clock::now();
    cout << "Computing time: " << duration_cast<milliseconds>(stop_time - start_time).count() << " ms\n";

    cout << "Extracting simplitigs and kmers counts..." << endl;
    spss.extract_simplitigs_and_counts();
    spss.print_stats();

    Encoder encoder(spss.get_simplitigs(), spss.get_counts(), params.debug);
    encoder.encode(params.encoding);
    encoder.print_stat();
    encoder.to_fasta_file(fasta_output);
    cout << "Simplitigs written to disk: " << fasta_output << endl;
    
    if (!params.skip_counts) {
        encoder.to_counts_file(counts_output);
        cout << "Counts written to disk: " << counts_output << endl;
    } else {
        cout << "Skipping counts file (flag -n enabled)\n";
    }
}

int main(int argc, char **argv) {
    cout << "===== Unitig STitch Advanced constRuction (USTAR) v" << VERSION << " =====\n";
    // cli parameters
    params_t params;
    parse_cli(argc, argv, params);
    print_params(params);

    if (params.batch_mode) {
        // Batch mode: read list of files from input file
        cout << "\n=== BATCH MODE ENABLED ===\n";
        cout << "Reading file list from: " << params.input_file_name << endl;
        
        ifstream file_list(params.input_file_name);
        if (!file_list.good()) {
            cerr << "Error: Cannot open file list: " << params.input_file_name << endl;
            exit(EXIT_FAILURE);
        }
        
        string output_prefix = params.fasta_file_name;  // Use -o flag as output directory prefix
        if (!output_prefix.empty() && output_prefix.back() != '/') {
            output_prefix += "/";  // Ensure it ends with /
        }
        
        string input_file;
        int file_count = 0;
        int success_count = 0;
        while (getline(file_list, input_file)) {
            // Skip empty lines
            if (input_file.empty()) continue;
            
            file_count++;
            
            // Check if file exists
            ifstream test_file(input_file);
            if (!test_file.good()) {
                cerr << "Warning: File not found, skipping: " << input_file << endl;
                continue;
            }
            test_file.close();
            
            try {
                process_single_file(input_file, params, output_prefix);
                success_count++;
            } catch (const exception &e) {
                cerr << "Error processing file " << input_file << ": " << e.what() << endl;
            }
        }
        
        file_list.close();
        cout << "\n=== BATCH PROCESSING COMPLETE ===\n";
        cout << "Files processed: " << success_count << "/" << file_count << endl;
        
    } else {
        // Single file mode: use custom output names if specified with -o and -c flags
        process_single_file(params.input_file_name, params, "", params.fasta_file_name, params.counts_file_name);
    }

    return EXIT_SUCCESS;
}
