"""
Using given mask to export roi of cell 
"""
function export_cell(track, imgs, edge_mask)
    height, width = size(imgs[:,:,1]);
    crop_img = zeros(700, 700, length(track)*20);
    for t in 1:length(track)
        x, y = Int.(floor.(track[t]));
        xmin, xmax, ymin, ymax = x-349 , x+350,  y-349, y+350
        if xmin < 1
            xmax = xmax - xmin + 1
            xmin = 1
        end
        if xmax > 1900
            xmin = xmin - (xmax-1900)
            xmax = 1900
        end
        if ymin < 1
            ymax = ymax - ymin +1
            ymin = 1
        end
        if ymax > 1300
            ymin = ymin - (ymax-1300)
            ymax = 1300
        end
        masked_cell= (edge_mask[:,:,t] .== edge_mask[x, y, t] )
        for i in 1:20
            crop_img[:,:,20*(t-1)+i] =(masked_cell.*imgs[:,:,20*(t-1)+i])[xmin:xmax, ymin:ymax]
        end
    end
    crop_img;
end

# TODO: run again and again until best fitting
"""
Extract nucleus from sperated cell
"""
function extract_nucleus( img, watershed_segments::SegmentedImage{Array{Int64,2},Float64} )
    img_clear = zeros(N0f16, size(watershed_segments.image_indexmap));
    img_blur = imfilter(img, Kernel.gaussian(9));
    for label in watershed_segments.segment_labels
        cell = img_blur .* (watershed_segments.image_indexmap .== label);
        # only select 70% brigter region or fixed area
        gmm = GMM(3, [pixel for pixel in real(cell) if pixel > 1e-5]);
        nucleus_th = sort(gmm.μ, dims=1)[end-1];
        img_clear .+= ( remove_small_area(cell .> nucleus_th)) .*img;
    end
    img_clear;
end#
"""
Choose cloest neighborhood
"""
function find_nearest(root, next_level, maxdistance)
    nucleus_distance = [sum(abs.(root .- next_level[i])) for i in 1:length(next_level)]
    mindist, mindist_index = findmin(nucleus_distance);
    if mindist < maxdistance
        return mindist_index
    else
        return nothing
    end
end

"""
Find every child with given root
"""
function buildtree(root::Int, position)
    tree = []
    height = length(position)
    level = 2
    child = find_nearest(position[1][root], position[level], 100);
    while( child ≠ nothing && level<height)
        push!(tree, child)
        child = find_nearest(position[level][child], position[level+=1], 100)
        #print("$level ")
    end
    tree
end

"""
Extract long-life path
"""
function generate_path(pos_map)
    all_path = []
    for root in 1:length(pos_map[1])
        tree = buildtree(root, pos_map);
        if length(tree) > 70
            path = [pos_map[i+1][tree[i]] for i in 1:length(tree) ];
            push!(all_path, path)
        end
    end
    all_path;
end
