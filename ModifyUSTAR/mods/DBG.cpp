//
// Created by enrico on 20/12/22.
//MOD

#include <fstream>
#include <iostream>
#include <cstring>
#include <algorithm>
#include "DBG.h"
#include "commons.h"

size_t DBG::estimate_n_nodes(){
    // minimum BCALM2 entry
    // >0 LN:i:31 ab:Z:2
    // AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    const uintmax_t MINIMUM_ENTRY_SIZE = 18 + kmer_size + 2;
    // auto file_size = std::filesystem::file_size(bcalm_file_name);
    auto file_size = 1000;
    return file_size / MINIMUM_ENTRY_SIZE;
}

void DBG::parse_bcalm_file() {
    ifstream bcalm_file;
    bcalm_file.open(bcalm_file_name);

    if(!bcalm_file.good()){
        cerr << "parse_bcalm_file(): Can't access file " << bcalm_file_name << endl;
        exit(EXIT_FAILURE);
    }

    // improve vector push_back() time
    nodes.reserve(estimate_n_nodes());
    size_t nodes_cap = nodes.capacity();
    if(debug)
        cout << "estimated number of unitigs: " << estimate_n_nodes() << endl;

    // start parsing two line at a time
    string line;
    while(getline(bcalm_file, line)){
        // escape comments
        if(line[0] == '#')
            continue;

        size_t serial; // BCALM2 serial
        char dyn_line[MAX_LINE_LEN]; // line after id and length

        // make a new node
        node_t node;

        // check if line fits in dyn_line
        if(line.size() > MAX_LINE_LEN){
            cerr << "parse_bcalm_file(): Lines must be smaller than " << MAX_LINE_LEN << " characters!" << endl;
            exit(EXIT_FAILURE);
        }

        // ------ parse line ------
        // Two supported formats:
        // 1) Standard BCALM2 format: >25 LN:i:32 ab:Z:14 12   L:-:23:+ L:-:104831:+  L:+:22:-
        //    - Simple numeric ID (e.g., "25")
        //    - Contains "LN:i:" for unitig length
        //    - Contains "ab:Z:" followed by space-separated integer abundances for each k-mer
        //
        // ########Cutterfish2 from the Logan project########
        // 2) Alternative format:     >SRR11905265_0 ka:f:1.0    L:-:27885434:- 
        //    - Named ID with underscore and number (e.g., "SRR11905265_0")
        //    - No "LN:i:" field (length computed from sequence)
        //    - Contains "ka:f:" followed by a single float value (average k-mer abundance)
        //    - Individual k-mer abundances are not provided, so we replicate the average

        // Check consistency: must have a def-line starting with '>'
        if(line[0] != '>'){
            cerr << "parse_bcalm_file(): Bad formatted input file: no def-line found!" << endl;
            exit(EXIT_FAILURE);
        }

        // AUTO-DETECT format type by searching for distinctive tags
        // Standard format has both "LN:i:" (length) and "ab:Z:" (abundance array)
        bool is_standard_format = (line.find("LN:i:") != string::npos && line.find("ab:Z:") != string::npos);
        // Alternative format has "ka:f:" (k-mer average as float)
        bool is_alternative_format = (line.find("ka:f:") != string::npos);

        // Validate that exactly one format is detected
        if(!is_standard_format && !is_alternative_format){
            cerr << "parse_bcalm_file(): Unknown file format! Expected either 'LN:i:' and 'ab:Z:' or 'ka:f:'" << endl;
            exit(EXIT_FAILURE);
        }

        if(is_standard_format){
            // STANDARD BCALM2 FORMAT PARSING
            // Example: >25 LN:i:32 ab:Z:14 12 L:-:23:+
            // Parse using scanf format: (skip '>') (read serial) (skip "LN:i:") (read length) (read rest)
            // format string breakdown:
            //   %*c    - skip '>' character
            //   %zd    - read serial number (size_t)
            //   %*5c   - skip 5 characters " LN:i"
            //   %d     - read unitig length (int)
            //   %[^\n]s - read rest of line until newline
            sscanf(line.c_str(), "%*c %zd %*5c %d %[^\n]s", &serial, &node.length, dyn_line);
        } else {// #### Cutterfish2 format ####
            // ALTERNATIVE FORMAT PARSING
            // Two supported patterns:
            // 1) Named: >SRR11905265_0 ka:f:1.0 L:-:27885434:-
            // 2) Simple: >0 ka:f:1.0 L:-:27885434:-
            
            // Find the underscore that separates prefix from serial number
            size_t underscore_pos = line.find('_');
            size_t space_pos = line.find(' ', 1); // Find first space after '>'
            
            if(underscore_pos != string::npos && underscore_pos < space_pos){
                // Pattern: NAME_NUMBER (e.g., >SRR11905265_0)
                // Extract the serial number: everything between '_' and first space
                string serial_str = line.substr(underscore_pos + 1, space_pos - underscore_pos - 1);
                serial = stoull(serial_str);  // Convert string to unsigned long long
            } else {
                // Pattern: NUMBER only (e.g., >0)
                // Extract the serial number: everything between '>' and first space
                string serial_str = line.substr(1, space_pos - 1);
                serial = stoull(serial_str);  // Convert string to unsigned long long
            }
            
            // Copy the rest of the line (after first space) to dyn_line for further parsing
            // This will contain: "ka:f:1.0 L:-:27885434:-"
            strcpy(dyn_line, line.substr(space_pos + 1).c_str());
            
            // Length is not provided in header, will be computed from sequence later
            node.length = 0;
        }

        // check consistency:
        // must have progressive IDs
        if(serial != nodes.size()){
            cerr << "parse_bcalm_file(): Bad formatted input file: lines must have progressive IDs!" << endl;
            exit(EXIT_FAILURE);
        }

        // ------ parse abundances ------
        char *token;
        if(is_standard_format){
            // STANDARD FORMAT: Parse array of k-mer abundances
            // dyn_line example: "ab:Z:14 12 17   L:-:23:+ L:-:104831:+  L:+:22:-"
            // Each integer between "ab:Z:" and first "L:" represents abundance of one k-mer
            
            uint32_t sum_abundance = 0;
            // Start tokenizing after "ab:Z:" (skip first 5 characters)
            token = strtok(dyn_line + 5, " ");
            do{
                uint32_t abundance = atoi(token);  // Convert token to integer
                sum_abundance += abundance;         // Accumulate for average calculation
                node.abundances.push_back(abundance);  // Store individual k-mer abundance
                token = strtok(nullptr, " ");       // Get next token
            }while(token != nullptr && token[0] != 'L');  // Stop when we hit arc definitions (L:...)
            
            // Calculate average abundance from all k-mer abundances
            node.average_abundance = sum_abundance / (double) node.abundances.size();
            // Calculate median abundance (requires sorting, done in median() function)
            node.median_abundance = median(node.abundances);
        } else {
            // ALTERNATIVE FORMAT: Parse single average k-mer abundance value
            // dyn_line example: "ka:f:1.0    L:-:27885434:-"
            // Only one float value representing the AVERAGE abundance across all k-mers
            
            double avg_abundance;
            // Extract the float value after "ka:f:"
            sscanf(dyn_line, "ka:f:%lf", &avg_abundance);
            
            // Store the average abundance as-is (it's already calculated in the file)
            node.average_abundance = avg_abundance;
            // Since we don't have individual k-mer values, use average for median too
            node.median_abundance = (uint32_t) avg_abundance;
            
            // NOTE: Individual k-mer abundances will be filled AFTER reading the sequence
            // (we need to know how many k-mers exist, which requires sequence length)
            // For now, just prepare to parse arcs
            
            // Find where arc definitions start (L: tags)
            token = strstr(dyn_line, "L:");
            if(token != nullptr){
                // Prepare for arc parsing: tokenize to position at first L: tag
                token = strtok(dyn_line, " ");  // First token is "ka:f:X.X"
                token = strtok(nullptr, " ");    // Move to first arc or next field
            }
        }

        // ------ parse arcs ------
        // token = "L:-:23:+ L:-:104831:+  L:+:22:-"
        while(token != nullptr){
            arc_t arc{};
            char s1, s2; // left and right signs
            sscanf(token, "%*2c %c %*c %d %*c %c", &s1, &arc.successor, &s2); // L:-:23:+
            arc.forward = (s1 == '+');
            arc.to_forward = (s2 == '+');
            node.arcs.push_back(arc);
            // next arcs
            token = strtok(nullptr, " ");
        }

        // ------ parse sequence line ------
        // TTGAAGGTAACGGATGTTCTAGTTTTTTCTCTTT}
        if(!getline(bcalm_file, line)){
            cerr << "parse_bcalm_file(): expected a sequence here!" << endl;
            exit(EXIT_FAILURE);
        }

        // ------ read sequence ------
        // Get the unitig sequence from the second line (DNA/RNA nucleotides)
        node.unitig = line;

        // ALTERNATIVE FORMAT ONLY: Finalize length and populate abundances array
        if(!is_standard_format){
            // Now that we have the sequence, we can compute the unitig length
            node.length = node.unitig.size();
            
            // Calculate how many k-mers are in this unitig
            // Formula: for a sequence of length L and k-mer size K, there are (L - K + 1) k-mers
            // Example: sequence "ACGTACGT" with k=3 has 6 k-mers: ACG, CGT, GTA, TAC, ACG, CGT
            size_t n_kmers = node.unitig.size() - kmer_size + 1;
            
            // Since we only have one average value, replicate it for each k-mer position
            // This is necessary because the rest of the code expects an abundance value per k-mer
            // We use the integer cast of average_abundance to maintain consistency
            for(size_t i = 0; i < n_kmers; i++){
                node.abundances.push_back((uint32_t) node.average_abundance);
            }
        }

        // CONSISTENCY CHECK: Verify that we have exactly one abundance value per k-mer
        // This should always be true if parsing was correct
        // Formula: number_of_kmers = sequence_length - kmer_size + 1
        if((node.unitig.size() - kmer_size + 1) != node.abundances.size()){
            cerr << "parse_bcalm_file(): Bad formatted input file: wrong number of abundances!" << endl;
            cerr << "parse_bcalm_file(): Sequence length: " << node.unitig.size() << endl;
            cerr << "parse_bcalm_file(): Expected k-mers: " << (node.unitig.size() - kmer_size + 1) << endl;
            cerr << "parse_bcalm_file(): Actual abundances: " << node.abundances.size() << endl;
            cerr << "parse_bcalm_file(): Also make sure that kmer_size=" << kmer_size << endl;
            exit(EXIT_FAILURE);
        }

        // save the node
        nodes.push_back(node);

        if(debug){
            if(nodes_cap != nodes.capacity()){
                cout << "parse_bcalm_file(): nodes capacity changed!\n";
                nodes_cap = nodes.capacity();
            }
        }
    }
    nodes.shrink_to_fit();
    bcalm_file.close();
}

DBG::DBG(const string &bcalm_file_name, uint32_t kmer_size, bool debug){
    this->bcalm_file_name = bcalm_file_name;
    this->kmer_size = kmer_size;
    this->debug = debug;

    // build the graph
    parse_bcalm_file();

    // compute graph parameters
    size_t sum_unitig_length = 0;
    double sum_abundances = 0;
    for(const auto &node : nodes) {
        n_arcs += node.arcs.size();
        n_kmers += node.abundances.size();
        sum_unitig_length += node.length;
        sum_abundances += node.average_abundance * (double) node.abundances.size();

        if(node.arcs.empty()) n_iso++;
    }
    avg_unitig_len = (double) sum_unitig_length / (double) nodes.size();
    avg_abundances = sum_abundances / (double) n_kmers;
}

DBG::~DBG() = default;

void DBG::print_stat() {
    cout << "\n";
    cout << "DBG stats:\n";
    cout << "   number of kmers:            " << n_kmers << "\n";
    cout << "   number of nodes:            " << nodes.size() << "\n";
    cout << "   number of isolated nodes:   " << n_iso << " (" << double (n_iso) / double (nodes.size()) * 100 << "%)\n";
    cout << "   number of arcs:             " << n_arcs << "\n";
    cout << "   graph density:              " << double (n_arcs) / double (8 * nodes.size()) * 100 << "%\n";
    cout << "   average unitig length:      " << avg_unitig_len << "\n";
    cout << "   average abundances:         " << avg_abundances << "\n";
    cout << "\n";
}

bool DBG::verify_overlaps() {
    for(const auto &node : nodes){
        for(const auto &arc : node.arcs)
            if(!overlaps(node, arc))
                return false;
    }
    return true;
}

bool DBG::overlaps(const node_t &node, const arc_t &arcs){
    string u1, u2;
    if (arcs.forward) // + --> +/-
        // last kmer_size - 1 characters
        u1 = node.unitig.substr(node.unitig.length() - kmer_size + 1);
    else // - --> +/-
        // first kmer_size - 1 characters reverse-complemented
        u1 = reverse_complement(node.unitig.substr(0, kmer_size - 1));

    if(arcs.to_forward) // +/- --> +
        // first kmer_size - 1 characters
        u2 = nodes[arcs.successor].unitig.substr(0, kmer_size - 1);
    else  // +/- --> -
        // last kmer_size - 1 characters reverse-complemented
        u2 = reverse_complement(nodes[arcs.successor].unitig.substr(nodes[arcs.successor].unitig.length() - kmer_size + 1));

    return u1 == u2;
}

string DBG::reverse_complement(const string &s) {
    string rc(s);

    for(size_t i = 0; i < s.length(); i++) {
        char c;
        switch (s[i]) {
            case 'A':
            case 'a':
                c = 'T';
                break;
            case 'C':
            case 'c':
                c = 'G';
                break;
            case 'T':
            case 't':
                c = 'A';
                break;
            case 'G':
            case 'g':
                c = 'C';
                break;
            default:
                cerr << "reverse_complement(): Unknown nucleotide!" << endl;
                exit(EXIT_FAILURE);
        }
        rc[s.length() - 1 - i] = c;
    }
    return rc;
}

void DBG::to_bcalm_file(const string &file_name) {
    ofstream file;
    file.open(file_name);

    int id = 0;
    for(const auto &node : nodes){
        // >3 LN:i:33 ab:Z:2 2 3    L:+:138996:+
        // CAAAACCAGACATAATAAAAATACTAATTAATG
        file << ">" << id++ << " LN:i:" << node.length << " ab:Z:";
        for(auto &ab : node.abundances)
            file << ab << " ";
        for(auto &arcs : node.arcs)
            file << "L:" << (arcs.forward ? "+" : "-") << ":" << arcs.successor << ":" << (arcs.to_forward ? "+" : "-") << " ";
        file << "\n" << node.unitig << "\n";
    }

    file.close();
}

bool DBG::validate(){
    string fasta_dbg = "unitigs.k"+ to_string(kmer_size) +".ustar.fa";
    to_bcalm_file(fasta_dbg);

    ifstream bcalm_dbg, this_dbg;
    bcalm_dbg.open(bcalm_file_name);
    this_dbg.open(fasta_dbg);

    string tok1, tok2;
    while(bcalm_dbg >> tok1 && this_dbg >> tok2)
        if(tok1 != tok2) {
            cerr << "Files differ here: " << tok1 << " != " <<  tok2.length() << endl;
            return false;
        }
    return true;
}

bool DBG::verify_input(){
    bool good = true;
    if (verify_overlaps())
        cout << "YES! DBG is an overlapping graph!\n";
    else {
        cout << "OOPS! DBG is NOT an overlapping graph\n";
        good = false;
    }
    if(validate())
        cout << "YES! DBG is the same as BCALM2 one!\n";
    else {
        cout << "OOPS! DBG is NOT the same as BCALM2 one!\n";
        good = false;
    }
    cout << endl;
    return good;
}

void DBG::get_nodes_from(node_idx_t node, vector<bool> &forwards, vector<node_idx_t> &to_nodes, vector<bool> &to_forwards, const vector<bool> &mask) {
    // vectors must be empty
    to_nodes.clear();
    to_forwards.clear();

    for(auto &arc : nodes.at(node).arcs){
        if(mask.at(arc.successor)) continue;
        to_nodes.push_back(arc.successor);
        forwards.push_back(arc.forward);
        to_forwards.push_back(arc.to_forward);
    }
}

void DBG::get_consistent_nodes_from(node_idx_t node, bool forward, vector<node_idx_t> &to_nodes, vector<bool> &to_forwards, const vector<bool> &mask) {
    // vectors must be empty
    to_nodes.clear();
    to_forwards.clear();

    for(auto &arc : nodes.at(node).arcs){
        if(mask.at(arc.successor)) continue;
        if(arc.forward == forward) { // consistent nodes only
            to_nodes.push_back(arc.successor);
            to_forwards.push_back(arc.to_forward);
        }
    }
}

string DBG::spell(const vector<node_idx_t> &path_nodes, const vector<bool> &forwards) {
    if(path_nodes.size() != forwards.size()){
        cerr << "spell(): Inconsistent path!" << endl;
        exit(EXIT_FAILURE);
    }
    if(path_nodes.empty()) {
        cerr << "spell(): You're not allowed to spell an empty path!" << endl;
        exit(EXIT_FAILURE);
    }

    string contig;
    // first node as a seed
    if(forwards[0])
        contig = nodes.at(path_nodes[0]).unitig;
    else
        contig = reverse_complement(nodes.at(path_nodes[0]).unitig);

    // extend the seed
    for(size_t i = 1; i < path_nodes.size(); i++){
        if(forwards[i])
            contig += nodes.at(path_nodes[i]).unitig.substr(kmer_size - 1);
        else {
            string unitig = nodes.at(path_nodes[i]).unitig;
            size_t len = unitig.length() - (kmer_size - 1);
            contig += reverse_complement(unitig.substr(0, len));
        }
    }

    return contig;
}

void DBG::get_counts(const vector<node_idx_t> &path_nodes, const vector<bool> &forwards, vector<uint32_t> &counts) {
    //          3 5
    // forward: A C T T
    //          5 3
    // rev-com: A A G T
    for (size_t i = 0; i < path_nodes.size(); i++)
        if (forwards[i]) // read forward
            for(uint32_t abundance : nodes.at(path_nodes[i]).abundances)
                counts.push_back(abundance);
        else // read backward
            for(int k = int (nodes.at(path_nodes[i]).abundances.size() - 1); k > -1; k--)
                counts.push_back(nodes.at(path_nodes[i]).abundances[k]);
}

bool DBG::check_path_consistency(const vector<node_idx_t> &path_nodes, const vector<bool> &forwards) {
    // one orientation for each node
    if(path_nodes.size() != forwards.size())
        return false;

    for(size_t i = 0; i < path_nodes.size() - 1; i++){
        bool found = false;
        // is there an arc leading to a consistent node?
        for(auto &arc : nodes.at(path_nodes[i]).arcs)
            // same node orientation and successor check
            if(arc.forward == forwards[i] && arc.successor == path_nodes[i + 1])
                found = true;
        if(!found)
            return false;
    }
    return true;
}

uint32_t DBG::get_n_kmers() const {
    return n_kmers;
}

uint32_t DBG::get_n_nodes() const {
    return nodes.size();
}

const node_t & DBG::get_node(node_idx_t node){
    return nodes.at(node);
}

uint32_t DBG::get_kmer_size() const {
    return kmer_size;
}

const vector<node_t> * DBG::get_nodes() {
    return &nodes;
}

