from PIL import Image, ImageOps  
import os


def jpg_to_hex(input_image_path, output_hex_path, target_size=(768, 512)):
    try:
        with Image.open(input_image_path) as img:
            print(f"Original size: {img.size}")

            img = img.resize(target_size, Image.Resampling.LANCZOS)

            img = img.transpose(Image.Transpose.FLIP_TOP_BOTTOM)

            print(f"Resized and Flipped to: {img.size}")

            img = img.convert('RGB')

            with open(output_hex_path, 'w') as f:
                count = 0
                for r, g, b in img.getdata():
                    f.write(f"{r:x}\n")
                    f.write(f"{g:x}\n")
                    f.write(f"{b:x}\n")
                    count += 1

            print(f"Success! Output saved to '{output_hex_path}'")
            print(f"Total hex lines written: {count * 3}")

    except FileNotFoundError:
        print(f"Error: The file '{input_image_path}' was not found.")
    except Exception as e:
        print(f"An error occurred: {e}")


if __name__ == "__main__":
    input_file = "py.jpg"
    output_file = "output_image.hex"
    jpg_to_hex(input_file, output_file, target_size=(768, 512))