module TestMain
using Test     #src

using StaticArrays, Plots

# At this point, we import the useful Dionysos sub-modules.
using Dionysos
const DI = Dionysos
const UT = DI.Utils
const DO = DI.Domain
const ST = DI.System
const SY = DI.Symbolic
const CO = DI.Control
const OP = DI.Optim
const AB = OP.Abstraction

# ### Definition of the system
# we can import the module containing the DCDC problem like this 
include(joinpath(dirname(dirname(pathof(Dionysos))), "problems", "dc_dc.jl"))

# and we can instantiate the DC system with the provided system
concrete_problem = DCDC.problem(; approx_mode = "growth")
concrete_system = concrete_problem.system

x0 = SVector(0.0, 0.0)
hx = SVector(2.0 / 4.0e3, 2.0 / 4.0e3)
state_grid = DO.GridFree(x0, hx)
u0 = SVector(1)
hu = SVector(1)
input_grid = DO.GridFree(u0, hu)

using JuMP
optimizer = MOI.instantiate(AB.SCOTSAbstraction.Optimizer)
MOI.set(optimizer, MOI.RawOptimizerAttribute("concrete_problem"), concrete_problem)
MOI.set(optimizer, MOI.RawOptimizerAttribute("state_grid"), state_grid)
MOI.set(optimizer, MOI.RawOptimizerAttribute("input_grid"), input_grid)
MOI.optimize!(optimizer)

abstract_controller = MOI.get(optimizer, MOI.RawOptimizerAttribute("abstract_controller"))
concrete_controller = MOI.get(optimizer, MOI.RawOptimizerAttribute("concrete_controller"))

@testset "SCOTS safety" begin
    @test length(abstract_controller.data) == 893803 #src
end

no_plot = false
@static if get(ENV, "CI", "false") == "false" &&
           (isdefined(@__MODULE__, :no_plot) && no_plot == false)
    # ### Trajectory display
    # We choose the number of steps `nsteps` for the sampled system, i.e. the total elapsed time: `nstep`*`tstep`
    # as well as the true initial state `x0` which is contained in the initial state-space defined previously.
    nstep = 300
    x0 = SVector(1.2, 5.6)
    x_traj, u_traj =
        CO.get_closed_loop_trajectory(concrete_system.f, concrete_controller, x0, nstep)

    fig = plot(; aspect_ratio = :equal)
    plot!(concrete_system.X)
    plot!(UT.DrawTrajectory(x_traj))
end
end
