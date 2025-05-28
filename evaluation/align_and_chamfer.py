import argparse
import numpy as np
import open3d as o3d
import torch
from pytorch3d.loss import chamfer_distance

def align_and_compute_chamfer(src_path: str, tgt_path: str, output_txt: str = "output.txt"):
    # 1. Load point clouds
    ace0_pcd = o3d.io.read_point_cloud(src_path)
    gt_pcd   = o3d.io.read_point_cloud(tgt_path)

    # 2. ICP Registration
    threshold = 1000.0
    trans_init = np.array([
        [ 0.862,  0.011, -0.507,  0.5],
        [-0.139,  0.967, -0.215,  0.7],
        [ 0.487,  0.255,  0.835, -1.4],
        [ 0.0,    0.0,    0.0,    1.0]
    ])
    reg_p2p = o3d.pipelines.registration.registration_icp(
        ace0_pcd, gt_pcd, threshold, trans_init,
        o3d.pipelines.registration.TransformationEstimationPointToPoint()
    )

    # Log ICP results
    with open(output_txt, "a") as f:
        f.write("=== ICP Registration Result ===\n")
        f.write(f"{reg_p2p}\n")
        f.write("Transformation matrix:\n")
        f.write(np.array2string(reg_p2p.transformation, precision=6, suppress_small=True))
        f.write("\n\n")

    # Apply transform & save transformed PLY
    ace0_pcd.transform(reg_p2p.transformation)
    transformed_ply = src_path.replace(".ply", "_trans.ply")
    o3d.io.write_point_cloud(transformed_ply, ace0_pcd)

    # 3. Chamfer distance
    source_tensor = torch.from_numpy(np.asarray(ace0_pcd.points)).float().unsqueeze(0)
    target_tensor = torch.from_numpy(np.asarray(gt_pcd.points)).float().unsqueeze(0)
    if torch.cuda.is_available():
        source_tensor = source_tensor.cuda()
        target_tensor = target_tensor.cuda()

    loss_chamfer, _ = chamfer_distance(
        source_tensor, target_tensor,
        batch_reduction="mean", point_reduction="mean"
    )

    with open(output_txt, "a") as f:
        f.write("=== Chamfer Distance ===\n")
        f.write(f"ACE0 Chamfer loss: {loss_chamfer.item():.6f}\n")

    print(f"ICP transform applied and saved to {transformed_ply}")
    print(f"Chamfer loss: {loss_chamfer.item():.6f}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Align a source PLY to a target PLY via ICP and compute Chamfer distance."
    )
    parser.add_argument(
        "--src", "-s",
        required=True,
        help="Path to the source point cloud (e.g. ace0.ply)"
    )
    parser.add_argument(
        "--tgt", "-t",
        required=True,
        help="Path to the target point cloud (e.g. gt_gl.ply)"
    )
    parser.add_argument(
        "--out", "-o",
        default="output.txt",
        help="Path to the output log file"
    )
    args = parser.parse_args()

    align_and_compute_chamfer(args.src, args.tgt, args.out)
