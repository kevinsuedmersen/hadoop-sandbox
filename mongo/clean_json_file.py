import json
import re
import argparse
import codecs


def read_json(src_filepath):
    with open(src_filepath, 'r', encoding='utf-8-sig') as file:
        json_file = json.load(file)
    return json_file

def replace_number_decimal(value):
    # Extract the number
    m = re.search('NumberDecimal("(.+?)")', value)
    number = m.group(1)

    # Replace the value with {"$numberDecimal":"<number>"}
    clean_value = f'{{"$numberDecimal":"{number}"}}'
    return clean_value

def clean_value(value):
    if 'NumberDecimal' in value:
        clean_value = replace_number_decimal(value)

    return clean_value

def save_json(json_file, dest_filepath):
    with open(dest_filepath, 'w') as file:
        json.dump(json_file, file)
    print(f'Saved json file to {dest_filepath}')

def main(src_filepath, dest_filepath):
    # Clean values
    json_file = read_json(src_filepath)
    for counter, doc in enumerate(json_file):
        for key, value in doc.items():
            doc[key] = clean_value(value)

        # Logging
        if counter % 100 == 0:
            print(f'Processed {(counter+1) * 100} documents')

    # Save output file
    save_json(json_file, dest_filepath)


if __name__ == '__main__':
    # Defining command line arguments
    parser = argparse.ArgumentParser(
        description="CLI-Tool for cleaning json file to be imported into MongoDB")
    parser.add_argument(
        "--src_filepath", type=str, nargs="?",
        help="Path to input file",
        default=None)
    parser.add_argument(
        "--dest_filepath", type=str, nargs="?",
        help="Path to output file",
        default=None)

    # Parsing and validating command line arguments
    args = parser.parse_args()
    assert args.src_filepath is not None, 'src_filepath must be provided'
    assert args.dest_filepath is not None, 'dest_filepath must be provided'

    # Run script
    main(args.src_filepath, args.dest_filepath)
