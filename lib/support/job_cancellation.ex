defmodule Support.JobCancellation do
  @moduledoc """
  Provides supporting code to help cancel jobs by sending messages to
  the PID handling the job.

  # Concept

  We allow to send a message to the process that should finish the
  job.  The worker can choose to validate this.  If information is
  sent to the service that the job is to be cancelled, the worker can
  halt work if it finds that suitable.

  The worker can flush all messages for stopping the work as they
  might overlap.

  # Use

  When you start a new job, flush the previous messages by calling
  Support.JobCancellation.flush to flush messages sent to you.  Do
  this when you start the work.

  When you reach a chunk where you could stop or exit, ask to see if
  you should stop working by calling
  Support.JobCancellation.cancelled?()

  When you called a worker and have it's pid, you can cancel it's work
  by calling Support.JobCancellation.cancel!(pid).

  # Architecture

  When a worker may stop the work its doing, we send it a message.  If
  the worker wants to know if it is cancelled, we simply check if such
  a message is available.  When a worker starts it simply flushes the
  queue so all received messages are cleaned up.

  # Caveats

  If messages take a long time to receive (more than the @wait_time)
  then it may be that the messages are not flushed correctly.  We
  could circumvent this by sharing an extra secret, yet that would
  cause us to pass down extra state which we're currently trying to
  skip.

  # Throwing exceptions on cancel

  When the work has been cancelled, you may want to throw an error to
  indicate work will not continue.  This module also defined an
  exception which you can raise/catch for that purpose.
  """

  defexception message: "Job cancelled"

  @special_cancel_message {:cancel_job, Support.JobCancellation}
  @receive_flush_timeout 0
  @receive_cancelled_timeout 0

  @spec flush() :: :ok
  @doc """
  Flushes the work to be done.
  """
  def flush do
    receive do
      @special_cancel_message -> :ok
    after
      @receive_flush_timeout -> :ok
    end
  end

  @doc """
  Indicates the work has been cancelled.  Note that this can only be
  called once for a single cancellation.
  """
  @spec cancelled?() :: boolean
  def cancelled? do
    receive do
      @special_cancel_message -> true
    after
      @receive_cancelled_timeout -> false
    end
  end

  @spec cancel!( pid ) :: :ok
  @doc """
  Cancels the work that should be done by the given worker pid.
  """
  def cancel!( pid ) do
    send( pid, @special_cancel_message )
    :ok
  end

end
