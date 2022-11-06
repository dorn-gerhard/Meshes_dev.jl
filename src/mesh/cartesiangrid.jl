# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

"""
    CartesianGrid(dims, origin, spacing)

A Cartesian grid with dimensions `dims`, lower left corner at `origin`
and cell spacing `spacing`. The three arguments must have the same length.

    CartesianGrid(dims, origin, spacing, offset)

A Cartesian grid with dimensions `dims`, with lower left corner of element
`offset` at `origin` and cell spacing `spacing`.

    CartesianGrid(start, finish, dims=dims)

Alternatively, construct a Cartesian grid from a `start` point (lower left)
to a `finish` point (upper right).

    CartesianGrid(start, finish, spacing)

Alternatively, construct a Cartesian grid from a `start` point to a `finish`
point using a given `spacing`.

    CartesianGrid(dims)
    CartesianGrid(dim1, dim2, ...)

Finally, a Cartesian grid can be constructed by only passing the dimensions
`dims` as a tuple, or by passing each dimension `dim1`, `dim2`, ... separately.
In this case, the origin and spacing default to (0,0,...) and (1,1,...).

## Examples

Create a 3D grid with 100x100x50 hexahedrons:

```julia
julia> CartesianGrid(100,100,50)
```

Create a 2D grid with 100x100 quadrangles and origin at (10.,20.) units:

```julia
julia> CartesianGrid((100,100),(10.,20.),(1.,1.))
```

Create a 1D grid from -1 to 1 with 100 segments:

```julia
julia> CartesianGrid((-1.,),(1.,), dims=(100,))
```
"""
struct CartesianGrid{Dim,T} <: Mesh{Dim,T}
  origin::Point{Dim,T}
  spacing::NTuple{Dim,T}
  offset::Dims{Dim}
  topology::GridTopology{Dim}

  function CartesianGrid{Dim,T}(dims, origin, spacing, offset) where {Dim,T}
    @assert all(>(0), dims) "dimensions must be positive"
    @assert all(>(0), spacing) "spacing must be positive"
    topology = GridTopology(dims)
    new(origin, spacing, offset, topology)
  end
end

CartesianGrid(dims::Dims{Dim}, origin::Point{Dim,T},
              spacing::NTuple{Dim,T},
              offset::Dims{Dim}=ntuple(i->1, Dim)) where {Dim,T} =
  CartesianGrid{Dim,T}(dims, origin, spacing, offset)

CartesianGrid(dims::Dims{Dim}, origin::NTuple{Dim,T},
              spacing::NTuple{Dim,T},
              offset::Dims{Dim}=ntuple(i->1, Dim)) where {Dim,T} =
  CartesianGrid{Dim,T}(dims, Point(origin), spacing, offset)

function CartesianGrid(start::Point{Dim,T}, finish::Point{Dim,T},
                       spacing::NTuple{Dim,T}) where {Dim,T}
  dims = Tuple(ceil.(Int, (finish - start) ./ spacing))
  origin = start
  offset = ntuple(i->1, Dim)
  CartesianGrid{Dim,T}(dims, origin, spacing, offset)
end

CartesianGrid(start::NTuple{Dim,T}, finish::NTuple{Dim,T},
              spacing::NTuple{Dim,T}) where {Dim,T} =
  CartesianGrid(Point(start), Point(finish), spacing)

function CartesianGrid(start::Point{Dim,T}, finish::Point{Dim,T};
                       dims::Dims{Dim}=ntuple(i->100, Dim)) where {Dim,T}
  origin  = start
  spacing = Tuple((finish - start) ./ dims)
  offset  = ntuple(i->1, Dim)
  CartesianGrid{Dim,T}(dims, origin, spacing, offset)
end

CartesianGrid(start::NTuple{Dim,T}, finish::NTuple{Dim,T};
              dims::Dims{Dim}=ntuple(i->100, Dim)) where {Dim,T} =
  CartesianGrid(Point(start), Point(finish); dims=dims)

function CartesianGrid{T}(dims::Dims{Dim}) where {Dim,T}
  origin  = ntuple(i->zero(T), Dim)
  spacing = ntuple(i->one(T), Dim)
  offset  = ntuple(i->1, Dim)
  CartesianGrid{Dim,T}(dims, origin, spacing, offset)
end

CartesianGrid{T}(dims::Vararg{Int,Dim}) where {Dim,T} = CartesianGrid{T}(dims)

CartesianGrid(dims::Dims{Dim}) where {Dim} = CartesianGrid{Float64}(dims)

CartesianGrid(dims::Vararg{Int,Dim}) where {Dim} = CartesianGrid{Float64}(dims)

Base.size(g::CartesianGrid) = size(g.topology)
spacing(g::CartesianGrid)   = g.spacing
offset(g::CartesianGrid)    = g.offset

cart2vert(g::CartesianGrid, ind::CartesianIndex) = cart2vert(g, ind.I)
cart2vert(g::CartesianGrid, ijk) =
  Point(coordinates(g.origin) .+ (ijk .- g.offset) .* g.spacing)

Base.minimum(g::CartesianGrid{Dim}) where {Dim} = cart2vert(g, ntuple(i->1, Dim))
Base.maximum(g::CartesianGrid{Dim}) where {Dim} = cart2vert(g, size(g) .+ 1)
Base.extrema(g::CartesianGrid{Dim}) where {Dim} = minimum(g), maximum(g)

==(g1::CartesianGrid, g2::CartesianGrid) =
  g1.topology == g2.topology && g1.spacing  == g2.spacing &&
  Tuple(g1.origin - g2.origin) == (g1.offset .- g2.offset) .* g1.spacing

# -----------------
# DOMAIN INTERFACE
# -----------------

function element(g::CartesianGrid{Dim}, ind::Int) where {Dim}
  topo = g.topology
  inds = CartesianIndices(size(topo) .+ 1)
  elem = element(topo, ind)
  type = pltype(elem)
  vert = [cart2vert(g, inds[i]) for i in indices(elem)]
  type(vert)
end

function centroid(g::CartesianGrid{Dim}, ind::Int) where {Dim}
  dims = size(g.topology)
  intcoords = CartesianIndices(dims)[ind]
  neworigin = coordinates(g.origin) .+ g.spacing ./ 2
  Point(ntuple(i -> neworigin[i] + (intcoords[i] - g.offset[i])*g.spacing[i], Dim))
end

Base.eltype(g::CartesianGrid) = typeof(g[1])

# ---------------
# MESH INTERFACE
# ---------------

function vertices(g::CartesianGrid)
  dims = size(g.topology)
  inds = CartesianIndices(dims .+ 1)
  vec([cart2vert(g, ind) for ind in inds])
end

# ----------------------------
# ADDITIONAL INDEXING METHODS
# ----------------------------

"""
    grid[istart:iend,jstart:jend,...]

Return a subgrid of the Cartesian `grid` using integer ranges
`istart:iend`, `jstart:jend`, ...
"""
Base.getindex(g::CartesianGrid{Dim}, r::Vararg{UnitRange{Int},Dim}) where {Dim} =
  getindex(g, CartesianIndex(first.(r)):CartesianIndex(last.(r)))

function Base.getindex(g::CartesianGrid{Dim}, I::CartesianIndices{Dim}) where {Dim}
  dims   = size(I)
  offset = g.offset .- first(I).I .+ 1
  CartesianGrid(dims, g.origin, g.spacing, offset)
end

Base.view(g::CartesianGrid{Dim}, I::CartesianIndices{Dim}) where {Dim} = getindex(g, I)

# -----------
# IO METHODS
# -----------

function Base.show(io::IO, g::CartesianGrid{Dim,T}) where {Dim,T}
  dims = join(size(g.topology), "×")
  print(io, "$dims CartesianGrid{$Dim,$T}")
end

function Base.show(io::IO, ::MIME"text/plain", g::CartesianGrid)
  println(io, g)
  println(io, "  minimum: ", minimum(g))
  println(io, "  maximum: ", maximum(g))
  print(  io, "  spacing: ", spacing(g))
end
