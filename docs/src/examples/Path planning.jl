using Test     #src
# # Example: Path planning problem
#
#md # [![Binder](https://mybinder.org/badge_logo.svg)](@__BINDER_ROOT_URL__/generated/Path planning.ipynb)
#md # [![nbviewer](https://img.shields.io/badge/show-nbviewer-579ACA.svg)](@__NBVIEWER_ROOT_URL__/generated/Path planning.ipynb)
#
# This example was borrowed from [1, IX. Examples, A] whose dynamics comes from the model given in [2, Ch. 2.4].
# This is a **reachability problem** for a **continuous system**.
#
# Let us consider the 3-dimensional state space control system of the form
# ```math
# \dot{x} = f(x, u)
# ```
# with $f: \mathbb{R}^3 × U ↦ \mathbb{R}^3$ given by
# ```math
# f(x,(u_1,u_2)) = \begin{bmatrix} u_1 \cos(α+x_3)\cos(α^{-1}) \\ u_1 \sin(α+x_3)\cos(α^{-1}) \\ u_1 \tan(u_2)  \end{bmatrix}
# ```
# and with $U = [−1, 1] \times [−1, 1]$ and $α = \arctan(\tan(u_2)/2)$. Here, $(x_1, x_2)$ is the position and $x_3$ is the
# orientation of the vehicle in the 2-dimensional plane. The control inputs $u_1$ and $u_2$ are the rear
# wheel velocity and the steering angle.
# The control objective is to drive the vehicle which is situated in a maze made of obstacles from an initial position to a target position.
#
#
# In order to study the concrete system and its symbolic abstraction in a unified framework, we will solve the problem
# for the sampled system with a sampling time $\tau$.
#
# The abstraction is based on a feedback refinment relation [1,V.2 Definition].
# Basically, this is equivalent to an alternating simulation relationship with the additional constraint that the input of the
# concrete and symbolic system preserving the relation must be identical.
# This allows to easily determine the controller of the concrete system from the abstraction controller by simply adding a quantization step.
#
# For the construction of the relations in the abstraction, it is necessary to over-approximate attainable sets of
# a particular cell. In this example, we consider the used of a growth bound function  [1, VIII.2, VIII.5] which is one of the possible methods to over-approximate
# attainable sets of a particular cell based on the state reach by its center. Therefore, it is used
# to compute the relations in the abstraction based on the feedback refinement relation.
#
# For this reachability problem, the abstraction controller is built by solving a fixed-point equation which consists in computing the the pre-image
# of the target set.

# First, let us import [StaticArrays](https://github.com/JuliaArrays/StaticArrays.jl) and [Plots].
using StaticArrays, Plots

# At this point, we import Dionysos.
using Dionysos
const DI = Dionysos
const UT = DI.Utils
const DO = DI.Domain
const ST = DI.System
const SY = DI.Symbolic
const CO = DI.Control
const PR = DI.Problem
const OP = DI.Optim
const AB = OP.Abstraction

# And the file defining the hybrid system for this problem
include(joinpath(dirname(dirname(pathof(Dionysos))), "problems", "path_planning.jl"))

# ### Definition of the problem

# Now we instantiate the problem using the function provided by [PathPlanning.jl](@__REPO_ROOT_URL__/problems/PathPlanning.jl) 
concrete_problem = PathPlanning.problem(; simple = true, approx_mode = "growth");
concrete_system = concrete_problem.system;

# ### Definition of the abstraction

# Definition of the grid of the state-space on which the abstraction is based (origin `x0` and state-space discretization `h`):
x0 = SVector(0.0, 0.0, 0.0);
h = SVector(0.2, 0.2, 0.2);
state_grid = DO.GridFree(x0, h);

# Definition of the grid of the input-space on which the abstraction is based (origin `u0` and input-space discretization `h`):
u0 = SVector(0.0, 0.0);
h = SVector(0.3, 0.3);
input_grid = DO.GridFree(u0, h);

# We now solve the optimal control problem with the `Abstraction.SCOTSAbstraction.Optimizer`.

using JuMP
optimizer = MOI.instantiate(AB.SCOTSAbstraction.Optimizer)
MOI.set(optimizer, MOI.RawOptimizerAttribute("concrete_problem"), concrete_problem)
MOI.set(optimizer, MOI.RawOptimizerAttribute("state_grid"), state_grid)
MOI.set(optimizer, MOI.RawOptimizerAttribute("input_grid"), input_grid)
MOI.optimize!(optimizer)

# Get the results
abstract_system = MOI.get(optimizer, MOI.RawOptimizerAttribute("abstract_system"))
abstract_problem = MOI.get(optimizer, MOI.RawOptimizerAttribute("abstract_problem"))
abstract_controller = MOI.get(optimizer, MOI.RawOptimizerAttribute("abstract_controller"))
concrete_controller = MOI.get(optimizer, MOI.RawOptimizerAttribute("concrete_controller"))

@test length(abstract_controller.data) == 19400 #src

# ### Trajectory display
# We choose a stopping criterion `reached` and the maximal number of steps `nsteps` for the sampled system, i.e. the total elapsed time: `nstep`*`tstep`
# as well as the true initial state `x0` which is contained in the initial state-space `_I_` defined previously.
nstep = 100
function reached(x)
    if x ∈ concrete_problem.target_set
        return true
    else
        return false
    end
end
x0 = SVector(0.4, 0.4, 0.0)
x_traj, u_traj = CO.get_closed_loop_trajectory(
    concrete_system.f,
    concrete_controller,
    x0,
    nstep;
    stopping = reached,
)

# Here we display the coordinate projection on the two first components of the state space along the trajectory.
fig = plot(; aspect_ratio = :equal);
# We display the concrete domain
plot!(concrete_system.X; color = :yellow, opacity = 0.5);

# We display the abstract domain
plot!(abstract_system.Xdom; color = :blue, opacity = 0.5);

# We display the concrete specifications
plot!(concrete_problem.initial_set; color = :green, opacity = 0.2);
plot!(concrete_problem.target_set; dims = [1, 2], color = :red, opacity = 0.2);

# We display the abstract specifications
plot!(
    SY.get_domain_from_symbols(abstract_system, abstract_problem.initial_set);
    color = :green,
);
plot!(
    SY.get_domain_from_symbols(abstract_system, abstract_problem.target_set);
    color = :red,
);

# We display the concrete trajectory
plot!(UT.DrawTrajectory(x_traj); ms = 0.5)

# ### References
# 1. G. Reissig, A. Weber and M. Rungger, "Feedback Refinement Relations for the Synthesis of Symbolic Controllers," in IEEE Transactions on Automatic Control, vol. 62, no. 4, pp. 1781-1796.
# 2. K. J. Aström and R. M. Murray, Feedback systems. Princeton University Press, Princeton, NJ, 2008.
