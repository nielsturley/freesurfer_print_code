import sys
import pymeshlab

subject = sys.argv[1].split('/')[-2]
print(f"Merging and smoothing {subject}'s brain...")

ms = pymeshlab.MeshSet()
ms.load_new_mesh(sys.argv[1] + '/cortical.stl')
ms.load_new_mesh(sys.argv[1] + '/subcortical.stl')
ms.apply_coord_laplacian_smoothing_scale_dependent(stepsmoothnum = 100, delta = pymeshlab.Percentage(0.1))
ms.generate_by_merging_visible_meshes()
ms.meshing_decimation_quadric_edge_collapse(targetfacenum = 200000)
ms.save_current_mesh(sys.argv[1] + '/final_smoothed.stl')
ms.save_current_mesh('/Volumes/Yorick/3dPrint/toPrint/' + subject + '.stl')