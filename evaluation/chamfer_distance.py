import argparse
import torch
import numpy as np
import open3d as o3d
from pytorch3d.loss import chamfer_distance

def parse_args():
    parser = argparse.ArgumentParser(
        description="Compute Chamfer distance between two point clouds.")
    parser.add_argument(
        "--source", "-s",
        type=str,
        required=True,
        help="Path to the source point cloud (.ply)")
    parser.add_argument(
        "--target", "-t",
        type=str,
        required=True,
        help="Path to the target (ground truth) point cloud (.ply)")
    parser.add_argument(
        "--output", "-o",
        type=str,
        default="output.txt",
        help="File to append the Chamfer loss to")
    parser.add_argument(
        "--device", "-d",
        type=str,
        default="cuda" if torch.cuda.is_available() else "cpu",
        help="Compute device ('cuda' or 'cpu')")
    return parser.parse_args()

def load_point_cloud(path):
    pcd = o3d.io.read_point_cloud(path)
    if not pcd.has_points():
        raise ValueError(f"No points found in: {path}")
    return np.asarray(pcd.points, dtype=np.float32)

def compute_and_write_loss(src_path, tgt_path, output_path, device):
    # Load
    src_np = load_point_cloud(src_path)
    tgt_np = load_point_cloud(tgt_path)

    # To tensor
    src = torch.from_numpy(src_np).unsqueeze(0).to(device)  # (1, N, 3)
    tgt = torch.from_numpy(tgt_np).unsqueeze(0).to(device)

    # Compute Chamfer distance
    loss, _ = chamfer_distance(
        src, tgt,
        batch_reduction="mean",
        point_reduction="mean"
    )

    # Append to file
    with open(output_path, "a") as f:
        f.write(f"{src_path.split('/')[-1]} vs {tgt_path.split('/')[-1]} Chamfer loss: {loss.item():.6f}\n")

    print(f"Chamfer loss = {loss.item():.6f} (written to {output_path})")

if __name__ == "__main__":
    args = parse_args()
    compute_and_write_loss(
        src_path=args.source,
        tgt_path=args.target,
        output_path=args.output,
        device=args.device
    )
