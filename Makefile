# --------------------------------------------------------------------------------
# Wiirdle Makefile
#
# Copyright (C) 2022  HTV04
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
# --------------------------------------------------------------------------------

build:
	@rm -rf dist
	@mkdir -p dist/sd/apps/wiirdle/data

	@cp -r res/* dist/sd/apps/wiirdle
	@cp -r src/* dist/sd/apps/wiirdle/data

	@cd dist/sd; zip -r -9 ../wiirdle.zip .

clean:
	@rm -rf dist
