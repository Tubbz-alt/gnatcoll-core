-----------------------------------------------------------------------
--                          G N A T C O L L                          --
--                                                                   --
--                 Copyright (C) 2003-2010, AdaCore                  --
--                                                                   --
-- GPS is free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- As a special exception, if other files instantiate generics  from --
-- this unit, or you link this  unit with other files to produce  an --
-- executable, this unit does not by itself cause the resulting exe- --
-- cutable  to be covered by  the  GNU General  Public License. This --
-- exception does not however  invalidate any other reasons why  the --
-- executable  file  might  be  covered  by  the  GNU General Public --
-- License.                                                          --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this program; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

package body GNATCOLL.Scripts.Impl is

   procedure Console_Command_Handler
     (Data : in out Callback_Data'Class; Command : String);
   --  Handles command related to Console class

   -------------------
   -- From_Instance --
   -------------------

   function From_Instance
     (Script : access Scripting_Language_Record'Class;
      Inst   : access Class_Instance_Record'Class) return Class_Instance
   is
      Result : Class_Instance (Initialized => True);
   begin
      --  Do not modify the refcount, it should have been initialized properly
      --  already.
      Inst.Script := Scripting_Language (Script);

      --  Do not use an aggregate to limit the number of calls to
      --  Adjust/Finalize
      Result.Data.Data := Class_Instance_Record_Access (Inst);
      Incref (Get_CIR (Result));
      return Result;
   end From_Instance;

   -----------------
   -- Insert_Text --
   -----------------

   procedure Insert_Text
     (Script  : access Scripting_Language_Record'Class;
      Console : Virtual_Console := null;
      Txt     : String;
      Hide    : Boolean := False) is
   begin
      if Hide
        or else (Console /= null and then Console.Hide_Output)
        or else (Script.Console /= null and then Script.Console.Hide_Output)
      then
         null;
         --  Insert_Log (Script, Console, Txt);

      elsif Console /= null then
         Insert_Text (Console, Txt);

      elsif Script.Console /= null then
         Insert_Text (Script.Console, Txt);
      end if;
   end Insert_Text;

   ----------------
   -- Insert_Log --
   ----------------

   procedure Insert_Log
     (Script  : access Scripting_Language_Record'Class;
      Console : Virtual_Console := null;
      Txt     : String) is
   begin
      if Console /= null then
         Insert_Log (Console, Txt);
      elsif Script.Console /= null then
         Insert_Log (Script.Console, Txt);
      end if;
   end Insert_Log;

   ------------------
   -- Insert_Error --
   ------------------

   procedure Insert_Error
     (Script  : access Scripting_Language_Record'Class;
      Console : Virtual_Console := null;
      Txt     : String) is
   begin
      if Console /= null then
         Insert_Error (Console, Txt);
      elsif Script.Console /= null then
         Insert_Error (Script.Console, Txt);
      end if;
   end Insert_Error;

   -------------------
   -- Insert_Prompt --
   -------------------

   procedure Insert_Prompt
     (Script  : access Scripting_Language_Record'Class;
      Console : Virtual_Console := null;
      Txt     : String)
   is
   begin
      if Console /= null then
         Insert_Prompt (Console, Txt);
      elsif Script.Console /= null then
         Insert_Prompt (Script.Console, Txt);
      end if;
   end Insert_Prompt;

   -----------------------------
   -- Console_Command_Handler --
   -----------------------------

   procedure Console_Command_Handler
     (Data : in out Callback_Data'Class; Command : String)
   is
      type Mode_Kinds is (Text, Log, Error);

      Text_Cst : aliased constant String := "text";
      Size_Cst : aliased constant String := "size";
      Mode_Cst : aliased constant String := "mode";
      Inst     : constant Class_Instance := Nth_Arg (Data, 1, Any_Class);
      Console  : Virtual_Console;
      Mode     : Mode_Kinds := Text;
   begin
      if Command = "write" then
         Name_Parameters (Data, (1 => Text_Cst'Unchecked_Access,
                                 2 => Mode_Cst'Unchecked_Access));

         if Number_Of_Arguments (Data) = 3 then
            begin
               Mode := Mode_Kinds'Value (Nth_Arg (Data, 3));
            exception
               when Constraint_Error =>
                  Set_Error_Msg (Data, "Wrong value for ""mode"" parameter");
                  return;
            end;
         end if;

         Console := Get_Data (Inst);
         if Console /= null then
            case Mode is
               when Text =>
                  Insert_Text (Console, Nth_Arg (Data, 2));

               when Log =>
                  Insert_Log (Console, Nth_Arg (Data, 2));

               when Error =>
                  Insert_Error (Console, Nth_Arg (Data, 2));
            end case;
         else
            Set_Error_Msg (Data, "Console was closed by user");
         end if;

      elsif Command = "clear" then
         Console := Get_Data (Inst);
         if Console /= null then
            Clear (Console);
         else
            Set_Error_Msg (Data, "Console was closed by user");
         end if;

      elsif Command = "flush" then
         null;
         --  Do nothing, only needed for compatibility with Python's
         --  stdout stream

      elsif Command = "isatty" then
         Set_Return_Value (Data, False);

      elsif Command = "read" then
         Name_Parameters (Data, (1 => Size_Cst'Unchecked_Access));
         Console := Get_Data (Inst);
         if Console /= null then
            Set_Return_Value
              (Data,
               Read (Console,
                     Size       => Nth_Arg (Data, 2, Integer'Last),
                     Whole_Line => False));
         else
            Set_Error_Msg (Data, "Console was closed by user");
         end if;

      elsif Command = "readline" then
         Name_Parameters (Data, (1 => Size_Cst'Unchecked_Access));
         Console := Get_Data (Inst);
         if Console /= null then
            Set_Return_Value
              (Data,
               Read (Console,
                     Size       => Nth_Arg (Data, 2, Integer'Last),
                     Whole_Line => True));
         else
            Set_Error_Msg (Data, "Console was closed by user");
         end if;
      end if;
   end Console_Command_Handler;

   ----------------------------
   -- Register_Console_Class --
   ----------------------------

   procedure Register_Console_Class
     (Repo  : Scripts_Repository;
      Class : Class_Type) is
   begin
      Register_Command
        (Repo, "write",
         Minimum_Args => 1,
         Maximum_Args => 2,
         Class        => Class,
         Handler      => Console_Command_Handler'Access);
      Register_Command
        (Repo, "clear",
         Class        => Class,
         Handler      => Console_Command_Handler'Access);
      Register_Command
        (Repo, "flush",
         Class        => Class,
         Handler      => Console_Command_Handler'Access);
      Register_Command
        (Repo, "isatty",
         Class        => Class,
         Handler      => Console_Command_Handler'Access);
      Register_Command
        (Repo, "read", 0, 1,
         Class        => Class,
         Handler      => Console_Command_Handler'Access);
      Register_Command
        (Repo, "readline", 0, 1,
         Class        => Class,
         Handler      => Console_Command_Handler'Access);
   end Register_Console_Class;

end GNATCOLL.Scripts.Impl;
