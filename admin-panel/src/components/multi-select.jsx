import * as React from "react";
import { Check, ChevronsUpDown } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import {
  Command,
  CommandInput,
  CommandItem,
  CommandList,
} from "@/components/ui/command";

export const MultiSelect = ({ options, selected, onChange }) => {
  const [open, setOpen] = React.useState(false);

  const toggleOption = (option) => {
    // Check if the option is already selected
    const isSelected = selected.some((item) => {
      // Handle both object and ID formats
      const selectedId = typeof item === "object" ? item.id : item;
      return selectedId === option.id;
    });

    if (isSelected) {
      // Remove the option
      onChange(
        selected.filter((item) => {
          const selectedId = typeof item === "object" ? item.id : item;
          return selectedId !== option.id;
        })
      );
    } else {
      // Add the option
      onChange([...selected, option]);
    }
  };

  const isOptionSelected = (option) => {
    return selected.some((item) => {
      const selectedId = typeof item === "object" ? item.id : item;
      return selectedId === option.id;
    });
  };

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button variant="outline" className="w-full justify-between">
          {selected.length > 0
            ? `${selected.length} player${
                selected.length > 1 ? "s" : ""
              } selected`
            : "Select Players"}
          <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
        </Button>
      </PopoverTrigger>

      <PopoverContent className="w-full p-0 max-h-64 overflow-y-auto">
        <Command>
          <CommandInput placeholder="Search player..." />
          <CommandList>
            {options.map((option) => {
              const isChecked = isOptionSelected(option);
              return (
                <CommandItem
                  key={option.id}
                  onSelect={() => toggleOption(option)}
                  className="flex justify-between"
                >
                  <span>{option.name}</span>
                  {isChecked && <Check className="w-4 h-4" />}
                </CommandItem>
              );
            })}
          </CommandList>
        </Command>
      </PopoverContent>
    </Popover>
  );
};
